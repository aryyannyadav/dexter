//
//  DexterActionConfirmationPolicy.swift
//  leanring-buddy
//

import Foundation

/// One-time approval tied to a specific action instance (required for MODERATE and HIGH).
struct DexterActionConfirmationGrant: Equatable {
    let actionId: UUID
    let riskLevelAtApprovalTime: DexterActionRiskLevel
}

struct DexterActionConfirmationContent: Equatable {
    let whatWillHappen: String
    let whyDexterWantsToDoIt: String
    let whereItWillHappen: String
    let recoveryWarning: String?
}

enum DexterActionConfirmationPolicy {
    static func requiresUserConfirmation(
        action: DexterAction,
        settings: DexterActionPermissionSettings,
        confirmationGrant: DexterActionConfirmationGrant?,
        observationBefore: DexterActionObservationSnapshot? = nil,
        isComputerControlAuthorizedForSession: Bool = false
    ) -> Bool {
        if isComputerControlAuthorizedForSession,
           DexterComputerControlAuthorizationScope.actionQualifiesForSessionReuse(action) {
            return false
        }

        let resolvedRiskLevel = DexterActionRiskClassifier.resolvedRiskLevel(for: action)
        let recoveryProfile = observationBefore.map {
            DexterActionRecoveryMetadataBuilder.recoveryProfile(for: action, observationBefore: $0)
        }
        let isIrreversibleAction = recoveryProfile?.reversible == false

        switch resolvedRiskLevel {
        case .readOnly:
            return false

        case .lowRisk:
            if isIrreversibleAction {
                return !hasValidGrant(for: action, grant: confirmationGrant, resolvedRiskLevel: resolvedRiskLevel)
            }
            if settings.autoApproveLowRiskActions {
                return false
            }
            return !hasValidGrant(for: action, grant: confirmationGrant, resolvedRiskLevel: resolvedRiskLevel)

        case .moderateRisk:
            return !hasValidGrant(for: action, grant: confirmationGrant, resolvedRiskLevel: resolvedRiskLevel)

        case .highRisk:
            return !hasValidGrant(for: action, grant: confirmationGrant, resolvedRiskLevel: resolvedRiskLevel)
        }
    }

    static func spokenSummaryWhenAwaitingConfirmation(_ content: DexterActionConfirmationContent) -> String {
        var message = """
        Dexter needs your approval in the menu bar panel before it can continue. \
        What will happen: \(content.whatWillHappen) \
        Why: \(content.whyDexterWantsToDoIt) \
        Where: \(content.whereItWillHappen)
        """
        if let recoveryWarning = content.recoveryWarning?.nonEmptyTrimmedValue {
            message += " Recovery: \(recoveryWarning)"
        }
        return message
    }

    private static func hasValidGrant(
        for action: DexterAction,
        grant: DexterActionConfirmationGrant?,
        resolvedRiskLevel: DexterActionRiskLevel
    ) -> Bool {
        guard let grant, grant.actionId == action.id else {
            return false
        }
        return grant.riskLevelAtApprovalTime == resolvedRiskLevel
    }
}

enum DexterActionConfirmationContentBuilder {
    static func build(action: DexterAction, context: DexterContext) -> DexterActionConfirmationContent {
        let activeApplicationName = context.activeApplication.localizedName ?? "the frontmost application"
        let activeWindowTitle = context.activeWindow.title ?? "the active window"
        let userRequest = context.userMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)

        let whyDexterWantsToDoIt: String
        if userRequest.isEmpty {
            whyDexterWantsToDoIt = "Dexter planned this step to complete the computer action you requested."
        } else {
            whyDexterWantsToDoIt = "You asked Dexter to handle this while you said: \"\(userRequest)\"."
        }

        let observationBefore = DexterActionObservationSnapshot.from(context: context)
        let recoveryProfile = DexterActionRecoveryMetadataBuilder.recoveryProfile(
            for: action,
            observationBefore: observationBefore
        )
        let recoveryWarning = DexterActionRecoveryCopy.irreversibilityWarning(for: recoveryProfile)

        return DexterActionConfirmationContent(
            whatWillHappen: action.humanReadableDescription,
            whyDexterWantsToDoIt: whyDexterWantsToDoIt,
            whereItWillHappen: "On this Mac, in \(activeApplicationName), window \"\(activeWindowTitle)\".",
            recoveryWarning: recoveryWarning
        )
    }
}

enum DexterActionRiskClassifier {
    private static let highRiskInstructionSignals = [
        "delete",
        "remove",
        "send",
        "purchase",
        "buy",
        "pay",
        "transfer",
        "wipe",
        "format",
        "shutdown",
        "system settings"
    ]

    static func resolvedRiskLevel(for action: DexterAction) -> DexterActionRiskLevel {
        if action.type == .runTask,
           let instruction = action.parameters["instruction"]?.lowercased(),
           highRiskInstructionSignals.contains(where: { instruction.contains($0) }) {
            return .highRisk
        }

        if action.type == .typeText,
           let text = action.parameters["text"]?.lowercased(),
           highRiskInstructionSignals.contains(where: { text.contains($0) }) {
            return .highRisk
        }

        return action.riskLevel
    }

    static func defaultRiskLevel(for actionType: DexterActionType) -> DexterActionRiskLevel {
        switch actionType {
        case .inspectScreen, .explainContent, .listRunningApplications:
            return .readOnly
        case .openApplication, .focusApplication, .openURL, .scroll, .navigate:
            return .lowRisk
        case .typeText, .select:
            return .moderateRisk
        case .quitApplication, .click, .keyboardShortcut, .runTask:
            return .highRisk
        case .fileOperation, .terminalOperation:
            return .moderateRisk
        }
    }
}
