//
//  DexterPointAskPresenceState.swift
//  leanring-buddy
//
//  Subtle overlay cursor semantics for Point + Ask (Ctrl+Option+D).
//

import Foundation

enum DexterPointAskPresenceState: String, Equatable {
    case ready = "READY"
    case targeted = "TARGETED"
    case thinking = "THINKING"

    var userFacingLabel: String {
        switch self {
        case .ready:
            return "Ready"
        case .targeted:
            return "Targeted"
        case .thinking:
            return "Thinking"
        }
    }

    static func resolve(
        activePointInvokeSession: DexterPointInvokeSession?,
        isPreparingPointInvokeSession: Bool,
        voiceInteractionState: DexterVoiceInteractionState
    ) -> DexterPointAskPresenceState {
        if isPreparingPointInvokeSession {
            return .thinking
        }

        switch voiceInteractionState {
        case .transcribing, .thinking:
            if activePointInvokeSession != nil {
                return .thinking
            }
        default:
            break
        }

        if activePointInvokeSession != nil {
            return .targeted
        }

        return .ready
    }
}
