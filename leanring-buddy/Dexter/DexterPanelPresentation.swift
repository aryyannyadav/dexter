//
//  DexterPanelPresentation.swift
//  leanring-buddy
//

import Foundation

enum DexterPanelVoiceActivationLabel: String, Equatable {
    case ready = "Voice ready"
    case pushToTalkDisabled = "Push-to-talk off"
    case listening = "Listening"
    case thinking = "Thinking"
    case speaking = "Speaking"
    case setup = "Setup required"
}

enum DexterPanelActionPhaseLabel: String, Equatable {
    case proposed = "Action proposed"
    case awaitingPermission = "Permission required"
    case executing = "Executing"
    case verifying = "Verifying"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case verificationUncertain = "Verification uncertain"
}

enum DexterPanelVerificationResultLabel: String, Equatable {
    case success = "Verified"
    case failed = "Verification failed"
    case uncertain = "Uncertain"
    case none = "—"
}

enum DexterPanelPresentation {
    static func voiceActivationLabel(
        interactionState: DexterVoiceInteractionState,
        isPushToTalkEnabled: Bool,
        hasCompletedSetup: Bool
    ) -> DexterPanelVoiceActivationLabel {
        guard hasCompletedSetup else { return .setup }
        if !isPushToTalkEnabled && interactionState == .idle {
            return .pushToTalkDisabled
        }
        switch interactionState {
        case .idle:
            return .ready
        case .listening:
            return .listening
        case .thinking:
            return .thinking
        case .speaking:
            return .speaking
        }
    }

    static func actionPhaseLabel(for action: DexterAction?) -> DexterPanelActionPhaseLabel? {
        guard let action else { return nil }
        switch action.state {
        case .proposed:
            return .proposed
        case .awaitingConfirmation:
            return .awaitingPermission
        case .approved, .executing:
            return .executing
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        case .verificationFailed:
            return .verificationUncertain
        }
    }

    static func verificationResultLabel(for action: DexterAction?) -> DexterPanelVerificationResultLabel {
        guard let action else { return .none }
        switch action.state {
        case .completed:
            return .success
        case .verificationFailed:
            return .uncertain
        case .failed:
            return .failed
        default:
            return .none
        }
    }

    static func taskStatusHeadline(for task: DexterTask?) -> String? {
        guard let task, !task.isTerminal else { return nil }
        return "\(task.title) · step \(task.progressLabel)"
    }

    static func taskStatusDetail(for task: DexterTask?) -> String? {
        guard let task, !task.isTerminal else { return nil }
        let stepTitle = task.currentStep?.title ?? "Planning"
        return "\(task.state.rawValue.replacingOccurrences(of: "_", with: " ")) — \(stepTitle)"
    }
}
