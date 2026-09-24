//
//  DexterExecutionSafetyGuard.swift
//  leanring-buddy
//

import Foundation

enum DexterExecutionSafetyGuard {
    struct PreExecutionDecision: Equatable {
        let isAllowed: Bool
        let userFacingMessage: String
        let stopCondition: String?
    }

    @MainActor
    static func evaluateBeforeExecution(
        action: DexterAction,
        envelope: DexterExecutionSafetyEnvelope,
        stateMachine: DexterExecutionStateMachine,
        confirmationGrant: DexterActionConfirmationGrant?,
        targetApplicationBundleIdentifier: String?,
        requestedPermissions: [String] = []
    ) -> PreExecutionDecision {
        let emergencyStopController = DexterEmergencyStopController.shared

        if emergencyStopController.blocksAllAutomation {
            return deny(
                message: "Dexter emergency stop is active. Clear the stop before running actions.",
                stopCondition: "emergency_stop"
            )
        }

        if DexterTrustSafetyPolicy.blocksExecution(
            permissionLevel: envelope.permissionLevel,
            isEmergencyStopActive: emergencyStopController.isEmergencyStopActive,
            isComputerControlGloballyEnabled: DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled
        ) {
            return deny(
                message: "Computer control is not available at the current permission level.",
                stopCondition: "permission_denied"
            )
        }

        if DexterModelSelfGrantDefense.actionAttemptsModelSelfGrant(action) {
            return deny(
                message: "Dexter rejected an action that attempted to grant its own permissions.",
                stopCondition: "policy_violation"
            )
        }

        if let untrusted = untrustedDescription(in: action) {
            return deny(message: untrusted, stopCondition: "untrusted_external_authority")
        }

        if stateMachine.snapshot.stepCount > envelope.maxSteps {
            return deny(message: "Dexter stopped: maximum steps exceeded.", stopCondition: "budget_exceeded")
        }

        if stateMachine.snapshot.toolsConsumed >= envelope.maxToolCalls {
            return deny(message: "Dexter stopped: maximum tool calls exceeded.", stopCondition: "budget_exceeded")
        }

        if stateMachine.snapshot.actionsConsumed >= envelope.maxActions {
            return deny(message: "Dexter stopped: maximum actions exceeded.", stopCondition: "budget_exceeded")
        }

        if !DexterTrustSafetyPolicy.isApplicationInScope(
            envelope: envelope,
            targetApplicationBundleIdentifier: targetApplicationBundleIdentifier
        ) {
            return deny(message: "This action is outside the allowed application scope.", stopCondition: "application_scope")
        }

        if !DexterTrustSafetyPolicy.isPermissionInScope(
            envelope: envelope,
            requestedPermissions: requestedPermissions
        ) {
            return deny(message: "This action requests permissions outside the allowed scope.", stopCondition: "permission_denied")
        }

        if confirmationGrant != nil,
           !DexterModelSelfGrantDefense.confirmationGrantIsUserOriginated(grant: confirmationGrant, action: action) {
            return deny(
                message: "Confirmation grants must come from the user approval UI, not model output.",
                stopCondition: "policy_violation"
            )
        }

        return PreExecutionDecision(isAllowed: true, userFacingMessage: "Safety checks passed.", stopCondition: nil)
    }

    private static func untrustedDescription(in action: DexterAction) -> String? {
        if DexterExternalContentAuthorityPolicy.containsAuthorityOverrideAttempt(action.humanReadableDescription) {
            return DexterExternalContentAuthorityPolicy.evaluateUntrustedContent(action.humanReadableDescription)
                .failureReason
        }
        return nil
    }

    private static func deny(message: String, stopCondition: String) -> PreExecutionDecision {
        PreExecutionDecision(isAllowed: false, userFacingMessage: message, stopCondition: stopCondition)
    }
}

private extension DexterExternalContentDecision {
    var failureReason: String? {
        switch self {
        case .trustedAsDataOnly:
            return nil
        case .untrustedAuthorityAttempt(let reason):
            return reason
        }
    }
}
