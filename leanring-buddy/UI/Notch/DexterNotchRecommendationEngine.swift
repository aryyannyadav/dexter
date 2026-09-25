//
//  DexterNotchRecommendationEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterNotchRecommendationEngine {
    struct Input: Equatable {
        let runtimeState: DexterRuntimeUIState
        let runtimeDetail: String
        let failurePresentation: DexterRuntimeUIFailurePresentation?
        let voiceInteractionState: DexterVoiceInteractionState
        let actionConfirmation: DexterActionConfirmationPresentation?
        let activeProfileName: String?
        let activeProfileId: UUID?
        let profileWorkSuggestions: [DexterProfileWorkSuggestion]
        let openAccountabilityTasks: [DexterAccountabilityTask]
        let integrations: [DexterIntegration]
        let capabilityDiscoveryReport: DexterOpenClawCapabilityDiscoveryReport
        let openClawGatewayConnected: Bool
        let lastUserMessageText: String?
        let agentCompletionSnapshot: DexterNotchAgentCompletionSnapshot?
        let lastFailedActionId: UUID?
        let lastFailedActionDescription: String?
        let userFirstName: String
        let evaluatedAt: Date
    }

    static func resolve(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        if let highPriority = resolveHighPriorityRecommendation(input: input, persistence: persistence) {
            return highPriority
        }

        if isAgentBusy(input: input) {
            return nil
        }

        let mediumCandidates = [
            integrationRecommendation(input: input, persistence: persistence),
            workSuggestionRecommendation(input: input, persistence: persistence),
            unfinishedTaskRecommendation(input: input, persistence: persistence)
        ].compactMap { $0 }

        if let highestMedium = mediumCandidates.max(by: { $0.priority < $1.priority }) {
            return highestMedium
        }

        return idleStatusRecommendation(input: input)
    }

    private static func resolveHighPriorityRecommendation(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        if let permission = permissionRequestRecommendation(input: input) {
            return permission
        }
        if let activeAgent = activeAgentRecommendation(input: input) {
            return activeAgent
        }
        if let failure = agentFailureRecommendation(input: input, persistence: persistence) {
            return failure
        }
        if let completion = agentCompletionRecommendation(input: input, persistence: persistence) {
            return completion
        }
        return nil
    }

    private static func isAgentBusy(input: Input) -> Bool {
        switch input.runtimeState {
        case .acting, .verifying, .planning, .waitingPermission, .thinking, .understanding, .listening:
            return true
        default:
            break
        }
        switch input.voiceInteractionState {
        case .listening, .transcribing, .thinking, .speaking:
            return true
        case .idle, .error:
            break
        }
        return input.actionConfirmation != nil
    }

    private static func permissionRequestRecommendation(input: Input) -> DexterNotchRecommendation? {
        guard let confirmation = input.actionConfirmation else { return nil }
        let identifier = "permission:\(confirmation.actionId.uuidString)"

        return DexterNotchRecommendation(
            id: identifier,
            kind: .permissionRequest,
            priority: .high,
            profileName: input.activeProfileName,
            sectionTitle: "PERMISSION",
            headline: confirmation.content.whatWillHappen,
            body: confirmation.content.whyDexterWantsToDoIt,
            primaryActionTitle: "Allow",
            secondaryActionTitle: "Not now",
            source: DexterNotchRecommendationSource(
                kind: .actionConfirmation,
                referenceIdentifier: confirmation.actionId.uuidString,
                displayDetail: confirmation.content.whereItWillHappen
            ),
            primaryAction: .approvePendingPermission,
            secondaryAction: .cancelPendingPermission
        )
    }

    private static func activeAgentRecommendation(input: Input) -> DexterNotchRecommendation? {
        guard isAgentBusy(input: input) else { return nil }
        guard input.actionConfirmation == nil else { return nil }

        let title: String
        switch input.runtimeState {
        case .acting:
            title = "Running action"
        case .verifying:
            title = "Verifying"
        case .planning, .waitingPermission:
            title = "Preparing action"
        case .thinking, .understanding:
            title = "Thinking"
        case .listening:
            title = "Listening"
        default:
            switch input.voiceInteractionState {
            case .speaking:
                title = "Speaking"
            case .listening, .transcribing:
                title = "Listening"
            case .thinking:
                title = "Thinking"
            default:
                title = "Working"
            }
        }

        return DexterNotchRecommendation(
            id: "active_agent:\(input.runtimeState.rawValue)",
            kind: .activeDexter,
            priority: .high,
            profileName: input.activeProfileName,
            sectionTitle: "ACTIVE",
            headline: title,
            body: input.runtimeDetail.isEmpty ? "Dexter is working on your request." : input.runtimeDetail,
            primaryActionTitle: "Open",
            secondaryActionTitle: nil,
            source: DexterNotchRecommendationSource(
                kind: .runtimeState,
                referenceIdentifier: input.runtimeState.rawValue,
                displayDetail: title
            ),
            primaryAction: .openDexterHome,
            secondaryAction: nil
        )
    }

    private static func agentFailureRecommendation(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        guard input.runtimeState == .failed || input.failurePresentation != nil else { return nil }
        let failureSummary = input.failurePresentation?.whatFailed
            ?? input.lastFailedActionDescription
            ?? "Something went wrong"
        let stableFailureKey = input.lastFailedActionId?.uuidString ?? String(failureSummary.hashValue)
        let identifier = "agent_failure:\(stableFailureKey)"
        let persistenceId = "notch_recommendation:\(identifier)"
        guard persistence.shouldOfferSuggestion(identifier: persistenceId, now: input.evaluatedAt) else { return nil }

        return DexterNotchRecommendation(
            id: identifier,
            kind: .agentFailure,
            priority: .high,
            profileName: input.activeProfileName,
            sectionTitle: input.activeProfileName ?? "DEXTER",
            headline: "Couldn't finish that.",
            body: failureSummary,
            primaryActionTitle: "Retry",
            secondaryActionTitle: "Explain",
            source: DexterNotchRecommendationSource(
                kind: .failedAction,
                referenceIdentifier: identifier,
                displayDetail: failureSummary
            ),
            primaryAction: .retryLastAgentAction,
            secondaryAction: .explainLastAgentFailure
        )
    }

    private static func agentCompletionRecommendation(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        guard let completion = input.agentCompletionSnapshot else { return nil }
        guard persistence.shouldOfferSuggestion(identifier: completion.persistenceIdentifier, now: input.evaluatedAt) else {
            return nil
        }

        return DexterNotchRecommendation(
            id: completion.persistenceIdentifier.replacingOccurrences(of: "notch_recommendation:", with: ""),
            kind: .agentCompletion,
            priority: .high,
            profileName: completion.profileName,
            sectionTitle: completion.profileName,
            headline: "✓ Finished",
            body: completion.summary,
            primaryActionTitle: "Open",
            secondaryActionTitle: "Dismiss",
            source: DexterNotchRecommendationSource(
                kind: .completedAction,
                referenceIdentifier: completion.persistenceIdentifier,
                displayDetail: completion.summary
            ),
            primaryAction: .openDexterHome,
            secondaryAction: .dismiss
        )
    }

    private static func integrationRecommendation(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        guard let lastUserMessage = input.lastUserMessageText,
              !lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let evaluationInput = DexterCapabilityAwareSuggestionEngine.EvaluationInput(
            userMessageText: lastUserMessage,
            integrations: input.integrations,
            capabilityDiscoveryReport: input.capabilityDiscoveryReport,
            gatewayConnected: input.openClawGatewayConnected
        )

        guard let capabilitySuggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(from: evaluationInput) else {
            return nil
        }

        guard persistence.shouldOfferSuggestion(
            identifier: capabilitySuggestion.persistenceIdentifier,
            now: input.evaluatedAt
        ) else {
            return nil
        }

        let notchIdentifier = "capability:\(capabilitySuggestion.integrationIdForSettings)"

        return DexterNotchRecommendation(
            id: notchIdentifier,
            kind: .integrationRecommendation,
            priority: .medium,
            profileName: input.activeProfileName,
            sectionTitle: "CAPABILITY",
            headline: capabilitySuggestion.headline,
            body: capabilitySuggestion.body,
            primaryActionTitle: capabilitySuggestion.primaryActionTitle,
            secondaryActionTitle: "Later",
            source: DexterNotchRecommendationSource(
                kind: .integrationCatalog,
                referenceIdentifier: capabilitySuggestion.integrationIdForSettings,
                displayDetail: capabilitySuggestion.requirement.intentSummary
            ),
            primaryAction: .openIntegrationSettings(integrationId: capabilitySuggestion.integrationIdForSettings),
            secondaryAction: .dismiss
        )
    }

    private static func workSuggestionRecommendation(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        guard let profileId = input.activeProfileId else { return nil }
        guard let suggestion = input.profileWorkSuggestions.first(where: { $0.dexterProfileId == profileId }) else {
            return nil
        }
        guard persistence.shouldOfferSuggestion(identifier: suggestion.persistenceIdentifier, now: input.evaluatedAt) else {
            return nil
        }

        let continueHeadline = suggestion.category == .pickUpWhereYouLeftOff
            ? "Pick up where you left off?"
            : "Continue with \(input.activeProfileName ?? "your Dexter")?"

        return DexterNotchRecommendation(
            id: "work:\(suggestion.id)",
            kind: .contextualSuggestion,
            priority: .medium,
            profileName: input.activeProfileName,
            sectionTitle: input.activeProfileName ?? "SUGGESTION",
            headline: continueHeadline,
            body: suggestion.body,
            primaryActionTitle: suggestion.primaryActionTitle,
            secondaryActionTitle: "Dismiss",
            source: DexterNotchRecommendationSource(
                kind: .profileWorkSuggestion,
                referenceIdentifier: suggestion.id,
                displayDetail: suggestion.source.displayDetail
            ),
            primaryAction: .executeProfileWorkSuggestion(suggestionId: suggestion.id, profileId: profileId),
            secondaryAction: .dismiss
        )
    }

    private static func unfinishedTaskRecommendation(
        input: Input,
        persistence: DexterSuggestionPersistenceStore
    ) -> DexterNotchRecommendation? {
        guard let task = input.openAccountabilityTasks.first else { return nil }
        let identifier = "task:\(task.id.uuidString)"
        let persistenceId = "notch_recommendation:\(identifier)"
        guard persistence.shouldOfferSuggestion(identifier: persistenceId, now: input.evaluatedAt) else { return nil }

        return DexterNotchRecommendation(
            id: identifier,
            kind: .unfinishedTask,
            priority: .medium,
            profileName: input.activeProfileName,
            sectionTitle: "TASK",
            headline: "Unfinished task",
            body: task.title,
            primaryActionTitle: "Continue",
            secondaryActionTitle: "Dismiss",
            source: DexterNotchRecommendationSource(
                kind: .accountabilityTask,
                referenceIdentifier: task.id.uuidString,
                displayDetail: task.title
            ),
            primaryAction: .continueAccountabilityTask(taskId: task.id),
            secondaryAction: .dismiss
        )
    }

    private static func idleStatusRecommendation(input: Input) -> DexterNotchRecommendation {
        let greeting = DexterHomeGreetingFormatter.greeting(firstName: input.userFirstName)
        return DexterNotchRecommendation(
            id: "status:idle",
            kind: .dexterStatus,
            priority: .low,
            profileName: input.activeProfileName,
            sectionTitle: "DEXTER",
            headline: input.activeProfileName ?? "Dexter",
            body: greeting,
            primaryActionTitle: "Open",
            secondaryActionTitle: nil,
            source: DexterNotchRecommendationSource(
                kind: .runtimeState,
                referenceIdentifier: input.runtimeState.rawValue,
                displayDetail: "idle"
            ),
            primaryAction: .openDexterHome,
            secondaryAction: nil
        )
    }

}
