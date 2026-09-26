//
//  DexterActionPermissionFailureClassifier.swift
//  leanring-buddy
//

import Foundation

enum DexterActionPermissionFailureOutcome: String {
    case permissionDenied = "PERMISSION_DENIED"
    case targetResolutionFailed = "TARGET_RESOLUTION_FAILED"
    case invalidActionArgument = "INVALID_ACTION_ARGUMENT"
}

enum DexterActionPermissionFailureClassifier {
    static func observabilityOutcome(
        action: DexterAction,
        permissionDecision: DexterActionPermissionDecision
    ) -> DexterActionPermissionFailureOutcome {
        let normalizedMessage = permissionDecision.message.lowercased()
        if normalizedMessage.contains("missing screen coordinates")
            || normalizedMessage.contains("could not resolve a click target") {
            return .targetResolutionFailed
        }
        if action.type == .click,
           action.parameters["x"] == nil,
           action.parameters["y"] == nil,
           action.parameters["elementRef"]?.nonEmptyTrimmedValue == nil {
            return .invalidActionArgument
        }
        return .permissionDenied
    }

    static func userFacingMessage(
        action: DexterAction,
        permissionDecision: DexterActionPermissionDecision
    ) -> String {
        switch observabilityOutcome(action: action, permissionDecision: permissionDecision) {
        case .targetResolutionFailed, .invalidActionArgument:
            let destinationLabel = action.parameters["uiDestination"]?.nonEmptyTrimmedValue
                ?? action.parameters["elementRef"]?.nonEmptyTrimmedValue
                ?? action.parameters["verificationHint"]?.nonEmptyTrimmedValue
            let applicationName = action.parameters["parentApplicationName"]?.nonEmptyTrimmedValue
                ?? action.parameters["applicationName"]?.nonEmptyTrimmedValue
            if let destinationLabel, let applicationName {
                return "I couldn't locate \(destinationLabel) in \(applicationName). Make sure that window is visible, then try again."
            }
            if let destinationLabel {
                return "I couldn't locate \(destinationLabel) in the current window. Make sure it's visible, then try again."
            }
            return "I couldn't resolve a target for that computer action."
        case .permissionDenied:
            return permissionDecision.message
        }
    }
}
