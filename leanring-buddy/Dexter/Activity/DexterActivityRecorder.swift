//
//  DexterActivityRecorder.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
protocol DexterActivityEventSink: AnyObject {
    func record(_ record: DexterActivityRecord)
}

@MainActor
final class DexterActivityRecorder: ObservableObject, DexterActivityEventSink {
    @Published private(set) var events: [DexterActivityRecord] = []

    private let store: DexterActivityStore

    init(store: DexterActivityStore) {
        self.store = store
        events = store.allEvents()
    }

    convenience init() {
        self.init(store: DexterActivityStore())
    }

    static func inMemoryForTesting() -> DexterActivityRecorder {
        DexterActivityRecorder(store: DexterActivityStore.inMemoryForTesting())
    }

    func record(_ record: DexterActivityRecord) {
        store.prepend(record)
        events = store.allEvents()
    }

    func recentEvents(
        forProfileId profileId: UUID?,
        includeGlobal: Bool = true,
        filter: DexterActivityFilter = .all,
        limit: Int = 20
    ) -> [DexterActivityRecord] {
        store.events(forProfileId: profileId, includeGlobal: includeGlobal, filter: filter, limit: limit)
    }

    func event(withId id: UUID) -> DexterActivityRecord? {
        store.event(withId: id)
    }

    // MARK: - Action pipeline

    func recordActionExecutionOutcome(
        outcome: DexterActionExecutionOutcome,
        linkage: DexterActivityLinkage,
        userRequest: String?
    ) {
        guard outcome.pendingConfirmation == nil else { return }

        let action = outcome.action
        let turnRecord = outcome.turnRecord

        let status = mapActionStatus(action: action, turnRecord: turnRecord)
        let title = actionTitle(for: action)
        let resultSummary = DexterActivitySummaryRedaction.safeUserFacingText(
            turnRecord?.userFacingExplanation ?? outcome.spokenSummary
        )
        let verificationSummary = verificationLabel(for: turnRecord, action: action)

        let detail = DexterActivityDetail(
            requestedUtterance: DexterActivitySummaryRedaction.safeUserFacingText(userRequest ?? "", maxLength: 320),
            actionLabel: action.humanReadableDescription,
            resultSummary: resultSummary,
            verificationSummary: verificationSummary,
            workspaceDisplayPath: nil,
            memoryContentPreview: nil,
            routineName: nil,
            suggestionTitle: nil
        )

        let summary = statusSubtitle(status: status, verificationSummary: verificationSummary)

        record(
            DexterActivityRecord(
                dexterProfileId: linkage.dexterProfileId,
                kind: .action,
                title: title,
                summary: summary,
                status: status,
                source: .actionPipeline,
                relatedConversationId: linkage.conversationId,
                relatedWorkspaceId: linkage.fileWorkspaceId,
                relatedActionId: action.id,
                detail: detail
            )
        )
    }

    // MARK: - Routines

    func recordRoutineRun(
        routine: DexterRoutine,
        startedAt: Date,
        succeeded: Bool,
        summary: String
    ) {
        let safeSummary = DexterActivitySummaryRedaction.safeUserFacingText(summary) ?? "Routine finished."
        record(
            DexterActivityRecord(
                dexterProfileId: routine.dexterProfileId,
                kind: .routine,
                title: routine.name,
                summary: safeSummary,
                status: succeeded ? .completed : .failed,
                timestamp: Date(),
                source: .routineRunner,
                relatedRoutineId: routine.id,
                detail: DexterActivityDetail(
                    requestedUtterance: nil,
                    actionLabel: nil,
                    resultSummary: safeSummary,
                    verificationSummary: succeeded ? "Completed" : "Failed",
                    workspaceDisplayPath: nil,
                    memoryContentPreview: nil,
                    routineName: routine.name,
                    suggestionTitle: nil
                )
            )
        )
    }

    // MARK: - Memory

    func recordMemorySaved(_ memory: DexterStructuredMemoryRecord) {
        guard memory.status == .active else { return }
        guard memory.permissions.mayIncludeInModelContext else { return }
        guard memory.source == .explicitUserUtterance || memory.source == .userConfirmed else { return }

        let preview = DexterActivitySummaryRedaction.safeUserFacingText(memory.content)
        guard let preview else { return }

        record(
            DexterActivityRecord(
                dexterProfileId: memory.dexterProfileId,
                kind: .memory,
                title: "Saved memory",
                summary: preview,
                status: .completed,
                source: .memoryStore,
                relatedMemoryId: memory.id,
                detail: DexterActivityDetail(
                    memoryContentPreview: preview
                )
            )
        )
    }

    func recordMemoryForgotten(
        contentPreview: String,
        memoryId: UUID,
        dexterProfileId: UUID?
    ) {
        guard let preview = DexterActivitySummaryRedaction.safeUserFacingText(contentPreview) else { return }
        record(
            DexterActivityRecord(
                dexterProfileId: dexterProfileId,
                kind: .memory,
                title: "Forgot memory",
                summary: preview,
                status: .completed,
                source: .memoryStore,
                relatedMemoryId: memoryId,
                detail: DexterActivityDetail(memoryContentPreview: preview)
            )
        )
    }

    // MARK: - Workspace

    func recordWorkspaceAdded(workspace: DexterFileWorkspace) {
        let pathLabel = workspace.locations.compactMap(\.lastResolvedPath).first
        let displayPath = pathLabel.map { DexterActivitySummaryRedaction.displaySafePath($0) }
        record(
            DexterActivityRecord(
                dexterProfileId: workspace.dexterProfileId,
                kind: .workspace,
                title: "Workspace added",
                summary: workspace.name,
                status: .completed,
                source: .workspaceService,
                relatedWorkspaceId: workspace.id,
                detail: DexterActivityDetail(workspaceDisplayPath: displayPath)
            )
        )
    }

    func recordWorkspaceRemoved(workspaceName: String, workspaceId: UUID, dexterProfileId: UUID) {
        record(
            DexterActivityRecord(
                dexterProfileId: dexterProfileId,
                kind: .workspace,
                title: "Workspace removed",
                summary: workspaceName,
                status: .completed,
                source: .workspaceService,
                relatedWorkspaceId: workspaceId
            )
        )
    }

    // MARK: - Suggestions

    func recordSuggestionAccepted(_ suggestion: DexterSuggestion) {
        let title = DexterActivitySummaryRedaction.safeUserFacingText(suggestion.title) ?? "Suggestion"
        record(
            DexterActivityRecord(
                dexterProfileId: suggestion.dexterProfileId,
                kind: .suggestion,
                title: "Suggestion accepted",
                summary: title,
                status: .completed,
                source: .suggestionService,
                detail: DexterActivityDetail(suggestionTitle: title)
            )
        )
    }

    // MARK: - Helpers

    private func actionTitle(for action: DexterAction) -> String {
        if let applicationName = action.parameters["applicationName"], !applicationName.isEmpty {
            switch action.type {
            case .openApplication:
                return "Opened \(applicationName)"
            case .quitApplication:
                return "Quit \(applicationName)"
            case .focusApplication:
                return "Focused \(applicationName)"
            default:
                break
            }
        }
        return action.humanReadableDescription
    }

    private func mapActionStatus(
        action: DexterAction,
        turnRecord: DexterActionTurnRecord?
    ) -> DexterActivityStatus {
        if let turnRecord {
            switch turnRecord.resultStatus {
            case .succeeded:
                return .verified
            case .partiallyVerified:
                return .partiallyVerified
            case .verificationFailed:
                return .failed
            case .refused, .awaitingPermission:
                return .needsPermission
            case .cancelled:
                return .cancelled
            case .failed, .unavailable:
                return .failed
            case .executing:
                return .running
            case .proposed:
                return .running
            }
        }
        switch action.state {
        case .completed:
            return .verified
        case .verificationFailed:
            return .failed
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        default:
            return .failed
        }
    }

    private func verificationLabel(
        for turnRecord: DexterActionTurnRecord?,
        action: DexterAction
    ) -> String? {
        guard let turnRecord else {
            return action.state == .completed ? "Verified" : "Not completed"
        }
        switch turnRecord.resultStatus {
        case .succeeded:
            return "Verified"
        case .partiallyVerified:
            return "Partially verified"
        case .verificationFailed:
            return "Not completed"
        case .cancelled:
            return "Cancelled"
        case .refused, .awaitingPermission:
            return "Needs permission"
        case .failed, .unavailable:
            return "Failed"
        case .executing, .proposed:
            return nil
        }
    }

    private func statusSubtitle(status: DexterActivityStatus, verificationSummary: String?) -> String? {
        switch status {
        case .verified:
            return verificationSummary ?? "Verified"
        case .completed:
            return "Completed"
        case .partiallyVerified:
            return "Partially verified"
        case .failed:
            return verificationSummary ?? "Failed"
        case .needsPermission:
            return "Needs permission"
        case .cancelled:
            return "Cancelled"
        case .timedOut:
            return "Timed out"
        case .running:
            return "Running"
        }
    }
}
