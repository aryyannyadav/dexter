//
//  DexterNotchState.swift
//  leanring-buddy
//

import Foundation

/// User-driven chrome around the notch (size / interaction), separate from live activity.
enum DexterNotchChromeMode: Equatable {
    case idle
    case hovering
    case expanded

    func contentSize(
        ambientState: DexterAmbientState,
        recommendation: DexterNotchRecommendation?
    ) -> CGSize {
        let showsRichContent = ambientState == .suggestion
            || ambientState == .permission
            || ambientState == .error
            || (recommendation.map { $0.priority >= .medium || $0.secondaryActionTitle != nil } ?? false)

        switch self {
        case .idle:
            let compactWidth: CGFloat = ambientState == .idle ? 88 : 148
            return CGSize(width: compactWidth, height: DexterMetrics.notchCompactHeight)
        case .hovering:
            let hoverHeight: CGFloat = showsRichContent ? 156 : 104
            return CGSize(width: 300, height: hoverHeight)
        case .expanded:
            let expandedHeight: CGFloat = showsRichContent
                ? DexterMetrics.notchExpandedHeight + 64
                : DexterMetrics.notchExpandedHeight - 12
            return CGSize(width: 320, height: expandedHeight)
        }
    }
}

/// Live application phases reflected in the notch UI.
enum DexterNotchActivityPhase: Equatable {
    case idle
    case listening
    case thinking
    case speaking
    case acting
    case verifying
    case error
}

struct DexterNotchPresentation {
    let chromeMode: DexterNotchChromeMode
    let activityPhase: DexterNotchActivityPhase
    let statusTitle: String
    let statusDetail: String
    let showsAttentionBadge: Bool

    var primaryPhase: DexterNotchActivityPhase {
        activityPhase == .idle ? .idle : activityPhase
    }
}

enum DexterNotchStateResolver {
    static func activityPhase(companionManager: CompanionManager) -> DexterNotchActivityPhase {
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

        let voiceState = companionManager.voiceInteractionState
        switch voiceState {
        case .listening:
            return .listening
        case .transcribing:
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

        if runtimeState == .thinking || runtimeState == .understanding || runtimeState == .listening {
            switch runtimeState {
            case .listening:
                return .listening
            case .thinking, .understanding:
                return .thinking
            default:
                break
            }
        }

        return .idle
    }

    static func statusCopy(
        activityPhase: DexterNotchActivityPhase,
        companionManager: CompanionManager
    ) -> (title: String, detail: String) {
        let runtimeStore = companionManager.dexterRuntimeUIStateStore
        switch activityPhase {
        case .listening:
            return ("Listening", "Hold to talk or type below")
        case .thinking:
            return ("Thinking", runtimeStore.statusDetail.isEmpty ? "Working on your request" : runtimeStore.statusDetail)
        case .speaking:
            return ("Speaking", "Dexter is responding")
        case .acting:
            return ("Acting", runtimeStore.statusDetail.isEmpty ? "Running an action" : runtimeStore.statusDetail)
        case .verifying:
            return ("Verifying", runtimeStore.statusDetail.isEmpty ? "Checking the result" : runtimeStore.statusDetail)
        case .error:
            let failure = runtimeStore.failurePresentation
            return (failure?.whatFailed ?? "Something went wrong", failure?.whatYouCanDoNext ?? "Try again")
        case .idle:
            return ("Ready", "Dexter is nearby")
        }
    }

    static func buildPresentation(
        chromeMode: DexterNotchChromeMode,
        companionManager: CompanionManager,
        showsAttentionBadge: Bool
    ) -> DexterNotchPresentation {
        let activityPhase = activityPhase(companionManager: companionManager)
        let copy = statusCopy(activityPhase: activityPhase, companionManager: companionManager)
        return DexterNotchPresentation(
            chromeMode: chromeMode,
            activityPhase: activityPhase,
            statusTitle: copy.title,
            statusDetail: copy.detail,
            showsAttentionBadge: showsAttentionBadge
        )
    }
}
