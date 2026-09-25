//
//  DexterAgentHUDPresentation.swift
//  leanring-buddy
//

import Foundation

enum DexterAgentHUDMode: Equatable {
    case hidden
    case running
    case permission
    case result
    case failure
}

struct DexterAgentHUDPresentation: Equatable {
    let mode: DexterAgentHUDMode
    let taskName: String
    let operationLabel: String
    let progressFraction: Double?
    let progressCaption: String?
    let openClawStatusLine: String?
    let verificationResultLabel: String?
    let failureHeadline: String?
    let failureDetail: String?
    let canOfferAlwaysAllow: Bool
}

enum DexterAgentHUDResolver {
    static func resolve(companionManager: CompanionManager, holdsTerminalResult: Bool) -> DexterAgentHUDPresentation {
        if let confirmation = companionManager.actionConfirmationPresentation {
            return permissionPresentation(companionManager: companionManager, confirmation: confirmation)
        }

        let snapshot = companionManager.dexterRuntimeUIStateStore.activeExecutionSnapshot
        let runtimeState = companionManager.dexterRuntimeUIStateStore.currentState

        if let snapshot {
            if snapshot.currentPhase == .completed {
                return resultPresentation(companionManager: companionManager, snapshot: snapshot, holdsTerminalResult: holdsTerminalResult)
            }
            if snapshot.currentPhase == .failed || snapshot.currentPhase == .cancelled {
                return failurePresentation(companionManager: companionManager, snapshot: snapshot, holdsTerminalResult: holdsTerminalResult)
            }
            return runningPresentation(companionManager: companionManager, snapshot: snapshot)
        }

        if runtimeState == .failed, let failure = companionManager.dexterRuntimeUIStateStore.failurePresentation {
            return DexterAgentHUDPresentation(
                mode: holdsTerminalResult ? .failure : .hidden,
                taskName: taskTitle(companionManager: companionManager),
                operationLabel: "Action failed",
                progressFraction: nil,
                progressCaption: nil,
                openClawStatusLine: companionManager.openClawGatewayStatusLine,
                verificationResultLabel: nil,
                failureHeadline: "Dexter couldn't complete that action.",
                failureDetail: failure.why,
                canOfferAlwaysAllow: false
            )
        }

        switch runtimeState {
        case .acting, .verifying, .waitingPermission, .planning, .understanding:
            return runningPresentation(
                companionManager: companionManager,
                snapshot: nil,
                runtimeState: runtimeState,
                statusDetail: companionManager.dexterRuntimeUIStateStore.statusDetail
            )
        default:
            return hiddenPresentation()
        }
    }

    static func shouldShowHUD(presentation: DexterAgentHUDPresentation) -> Bool {
        presentation.mode != .hidden
    }

    private static func hiddenPresentation() -> DexterAgentHUDPresentation {
        DexterAgentHUDPresentation(
            mode: .hidden,
            taskName: "",
            operationLabel: "",
            progressFraction: nil,
            progressCaption: nil,
            openClawStatusLine: nil,
            verificationResultLabel: nil,
            failureHeadline: nil,
            failureDetail: nil,
            canOfferAlwaysAllow: false
        )
    }

    private static func permissionPresentation(
        companionManager: CompanionManager,
        confirmation: DexterActionConfirmationPresentation
    ) -> DexterAgentHUDPresentation {
        let canAlwaysAllow = confirmation.riskLevel == .lowRisk
        return DexterAgentHUDPresentation(
            mode: .permission,
            taskName: taskTitle(companionManager: companionManager),
            operationLabel: confirmation.content.whatWillHappen,
            progressFraction: nil,
            progressCaption: confirmation.content.whereItWillHappen,
            openClawStatusLine: companionManager.openClawGatewayStatusLine,
            verificationResultLabel: nil,
            failureHeadline: nil,
            failureDetail: confirmation.content.whyDexterWantsToDoIt,
            canOfferAlwaysAllow: canAlwaysAllow
        )
    }

    private static func runningPresentation(
        companionManager: CompanionManager,
        snapshot: DexterExecutionMachineSnapshot
    ) -> DexterAgentHUDPresentation {
        let progress = progressValues(from: snapshot)
        return DexterAgentHUDPresentation(
            mode: .running,
            taskName: taskTitle(companionManager: companionManager),
            operationLabel: operationLabel(for: snapshot),
            progressFraction: progress.fraction,
            progressCaption: progress.caption,
            openClawStatusLine: companionManager.openClawGatewayStatusLine,
            verificationResultLabel: nil,
            failureHeadline: nil,
            failureDetail: nil,
            canOfferAlwaysAllow: false
        )
    }

    private static func runningPresentation(
        companionManager: CompanionManager,
        snapshot: DexterExecutionMachineSnapshot?,
        runtimeState: DexterRuntimeUIState,
        statusDetail: String
    ) -> DexterAgentHUDPresentation {
        DexterAgentHUDPresentation(
            mode: .running,
            taskName: taskTitle(companionManager: companionManager),
            operationLabel: operationLabel(for: runtimeState, detail: statusDetail),
            progressFraction: nil,
            progressCaption: statusDetail.isEmpty ? nil : statusDetail,
            openClawStatusLine: companionManager.openClawGatewayStatusLine,
            verificationResultLabel: nil,
            failureHeadline: nil,
            failureDetail: nil,
            canOfferAlwaysAllow: false
        )
    }

    private static func resultPresentation(
        companionManager: CompanionManager,
        snapshot: DexterExecutionMachineSnapshot,
        holdsTerminalResult: Bool
    ) -> DexterAgentHUDPresentation {
        let verificationLabel = verificationLabel(for: snapshot.verificationStatus)
        return DexterAgentHUDPresentation(
            mode: holdsTerminalResult ? .result : .hidden,
            taskName: taskTitle(companionManager: companionManager),
            operationLabel: verificationLabel ?? "Could not verify",
            progressFraction: 1,
            progressCaption: snapshot.progressSummary,
            openClawStatusLine: nil,
            verificationResultLabel: verificationLabel,
            failureHeadline: nil,
            failureDetail: nil,
            canOfferAlwaysAllow: false
        )
    }

    private static func failurePresentation(
        companionManager: CompanionManager,
        snapshot: DexterExecutionMachineSnapshot,
        holdsTerminalResult: Bool
    ) -> DexterAgentHUDPresentation {
        let detail = snapshot.errorInfo?.message
            ?? companionManager.dexterRuntimeUIStateStore.failurePresentation?.why
            ?? companionManager.openClawGatewayStatusLine
        return DexterAgentHUDPresentation(
            mode: holdsTerminalResult ? .failure : .hidden,
            taskName: taskTitle(companionManager: companionManager),
            operationLabel: "Action interrupted",
            progressFraction: nil,
            progressCaption: nil,
            openClawStatusLine: companionManager.openClawGatewayStatusLine,
            verificationResultLabel: nil,
            failureHeadline: "Dexter couldn't complete that action.",
            failureDetail: detail,
            canOfferAlwaysAllow: false
        )
    }

    private static func taskTitle(companionManager: CompanionManager) -> String {
        if let workflowTitle = companionManager.panelActiveWorkflowTask?.title, !workflowTitle.isEmpty {
            return workflowTitle
        }
        if let taskDescription = companionManager.dexterActiveTaskDescription, !taskDescription.isEmpty {
            return taskDescription
        }
        if let actionTitle = companionManager.panelLastTypedAction?.type.rawValue, !actionTitle.isEmpty {
            return actionTitle
        }
        return "Computer action"
    }

    private static func operationLabel(for snapshot: DexterExecutionMachineSnapshot) -> String {
        let summary = snapshot.progressSummary?.lowercased() ?? ""
        if summary.contains("safari") || summary.contains("browser") {
            if snapshot.currentPhase == .executing { return "Opening Safari…" }
        }
        if summary.contains("click") { return "Clicking…" }
        if summary.contains("type") || summary.contains("typing") { return "Typing…" }
        if summary.contains("wait") { return "Waiting…" }

        switch snapshot.currentPhase {
        case .received, .understanding:
            return "Understanding…"
        case .planning:
            return "Planning…"
        case .waitingPermission:
            return "Waiting for permission…"
        case .executing:
            return snapshot.progressSummary ?? "Acting…"
        case .verifying:
            return "Verifying…"
        case .completed, .failed, .cancelled:
            return snapshot.progressSummary ?? "Finishing…"
        }
    }

    private static func operationLabel(for state: DexterRuntimeUIState, detail: String) -> String {
        if !detail.isEmpty { return detail }
        switch state {
        case .understanding:
            return "Understanding…"
        case .planning:
            return "Planning…"
        case .waitingPermission:
            return "Waiting…"
        case .acting:
            return "Acting…"
        case .verifying:
            return "Verifying…"
        default:
            return "Working…"
        }
    }

    private static func progressValues(from snapshot: DexterExecutionMachineSnapshot) -> (fraction: Double?, caption: String?) {
        guard snapshot.actionBudget > 0 else {
            return (nil, snapshot.progressSummary)
        }
        let fraction = min(1, Double(snapshot.actionsConsumed) / Double(snapshot.actionBudget))
        let caption = "Step \(snapshot.actionsConsumed) of \(snapshot.actionBudget)"
        return (fraction, caption)
    }

    private static func verificationLabel(for status: DexterActionVerificationStatus?) -> String? {
        switch status {
        case .verified, .partiallyVerified:
            return "Verified"
        case .failed, .unavailable:
            return "Could not verify"
        case .none:
            return nil
        }
    }
}
