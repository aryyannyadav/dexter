//
//  DexterCharacterState.swift
//  leanring-buddy
//

import Foundation

enum DexterCharacterState: String, Equatable, CaseIterable {
    case idle
    case listening
    case thinking
    case speaking
    case working
    case success
    case error
    case sleeping

    var accessibilityLabel: String {
        switch self {
        case .idle: return "ready"
        case .listening: return "listening"
        case .thinking: return "thinking"
        case .speaking: return "speaking"
        case .working: return "working"
        case .success: return "completed"
        case .error: return "error"
        case .sleeping: return "resting"
        }
    }

    /// Higher priority wins when multiple signals are active.
    var priority: Int {
        switch self {
        case .error: return 70
        case .success: return 60
        case .working: return 50
        case .speaking: return 40
        case .listening: return 30
        case .thinking: return 20
        case .idle: return 10
        case .sleeping: return 5
        }
    }

    var isTransient: Bool {
        self == .success || self == .error
    }
}

enum DexterCharacterStateResolver {
    static func resolve(
        companionManager: CompanionManager,
        ephemeralOverride: DexterCharacterState?,
        isApplicationActive: Bool
    ) -> DexterCharacterState {
        if let ephemeralOverride {
            return ephemeralOverride
        }

        let candidates = collectActiveCandidates(companionManager: companionManager)

        if !isApplicationActive, candidates.allSatisfy({ $0 == .idle || $0.isTransient }) {
            return .sleeping
        }

        return candidates.max(by: { $0.priority < $1.priority }) ?? .idle
    }

    private static func collectActiveCandidates(companionManager: CompanionManager) -> [DexterCharacterState] {
        var candidates: [DexterCharacterState] = [.idle]

        let runtimeStore = companionManager.dexterRuntimeUIStateStore
        let runtimeState = runtimeStore.currentState

        if runtimeStore.failurePresentation != nil || runtimeState == .failed {
            candidates.append(.error)
        }

        switch runtimeState {
        case .acting, .verifying, .planning, .waitingPermission:
            candidates.append(.working)
        case .thinking, .understanding:
            candidates.append(.thinking)
        case .listening:
            candidates.append(.listening)
        default:
            break
        }

        if companionManager.isAssistantAudioSpeaking {
            candidates.append(.speaking)
        }

        switch companionManager.voiceInteractionState {
        case .listening, .transcribing:
            candidates.append(.listening)
        case .speaking:
            candidates.append(.speaking)
        case .thinking:
            candidates.append(.thinking)
        case .error:
            candidates.append(.error)
        case .idle:
            break
        }

        return candidates
    }

    static func mapLegacyAvatarState(_ avatarState: DexterAvatarState) -> DexterCharacterState {
        switch avatarState {
        case .idle: return .idle
        case .listening: return .listening
        case .thinking: return .thinking
        case .speaking: return .speaking
        case .acting, .verifying: return .working
        case .success: return .success
        case .error: return .error
        case .sleeping: return .sleeping
        }
    }
}
