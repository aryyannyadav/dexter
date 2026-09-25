//
//  DexterAvatarState.swift
//  leanring-buddy
//

import Foundation

enum DexterAvatarState: String, Equatable, CaseIterable {
    case idle
    case listening
    case thinking
    case speaking
    case acting
    case verifying
    case success
    case error
    case sleeping

    var accessibilityLabel: String {
        switch self {
        case .idle: return "Dexter is ready"
        case .listening: return "Dexter is listening"
        case .thinking: return "Dexter is thinking"
        case .speaking: return "Dexter is speaking"
        case .acting: return "Dexter is acting"
        case .verifying: return "Dexter is verifying"
        case .success: return "Task completed"
        case .error: return "Something went wrong"
        case .sleeping: return "Dexter is resting"
        }
    }
}

enum DexterAvatarStateResolver {
    static func resolveActivity(companionManager: CompanionManager) -> DexterAvatarState {
        let runtimeStore = companionManager.dexterRuntimeUIStateStore
        let runtimeState = runtimeStore.currentState

        if runtimeStore.failurePresentation != nil || runtimeState == .failed {
            return .error
        }
        if runtimeState == .verifying {
            return .verifying
        }
        if runtimeState == .acting || runtimeState == .waitingPermission || runtimeState == .planning {
            return .acting
        }

        switch companionManager.voiceInteractionState {
        case .listening, .transcribing:
            return .listening
        case .speaking:
            return .speaking
        case .thinking:
            return .thinking
        case .error:
            return .error
        case .idle:
            break
        }

        if runtimeState == .thinking || runtimeState == .understanding {
            return .thinking
        }
        if runtimeState == .listening {
            return .listening
        }

        return .idle
    }

    static func resolve(
        companionManager: CompanionManager,
        ephemeralOverride: DexterAvatarState?,
        isApplicationActive: Bool
    ) -> DexterAvatarState {
        if let ephemeralOverride {
            return ephemeralOverride
        }

        let activity = resolveActivity(companionManager: companionManager)
        if activity != .idle {
            return activity
        }

        if !isApplicationActive {
            return .sleeping
        }

        return .idle
    }
}
