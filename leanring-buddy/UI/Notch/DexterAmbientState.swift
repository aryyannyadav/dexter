//
//  DexterAmbientState.swift
//  leanring-buddy
//

import Foundation

/// Ambient notch / companion surface phases (presentation only).
enum DexterAmbientState: Equatable {
    case idle
    case listening
    case thinking
    case working
    case speaking
    case suggestion
    case permission
    case success
    case error
}

struct DexterAmbientResolvedState: Equatable {
    let ambientState: DexterAmbientState
    let statusTitle: String
    let statusDetail: String
    let characterState: DexterCharacterState
    let activeProfileName: String
    let phase5Suggestion: DexterHomeSuggestionItem?
    let notchRecommendation: DexterNotchRecommendation?

    var accessibilityLabel: String {
        switch ambientState {
        case .idle:
            return "Dexter, ready"
        case .listening:
            return "Dexter, listening"
        case .thinking:
            return "Dexter, thinking"
        case .working:
            return "Dexter, working"
        case .speaking:
            return "Dexter, speaking"
        case .suggestion:
            let title = phase5Suggestion?.title ?? notchRecommendation?.headline ?? "suggestion"
            return "Dexter suggestion: \(title)"
        case .permission:
            return "Dexter, permission required"
        case .success:
            return "Dexter, done"
        case .error:
            return "Dexter, something went wrong"
        }
    }

    var compactStatusLine: String {
        switch ambientState {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening…"
        case .thinking:
            return "Thinking…"
        case .working:
            return statusTitle
        case .speaking:
            return "Speaking…"
        case .suggestion:
            return phase5Suggestion?.title ?? notchRecommendation?.headline ?? "Suggestion"
        case .permission:
            return "Permission"
        case .success:
            return "Done"
        case .error:
            return "Error"
        }
    }
}

enum DexterAmbientStateResolver {
    static func resolve(
        companionManager: CompanionManager,
        notchRecommendation: DexterNotchRecommendation?,
        phase5Suggestion: DexterHomeSuggestionItem?,
        ephemeralSuccessActive: Bool,
        productCapabilities: [DexterProductCapability]
    ) -> DexterAmbientResolvedState {
        let runtimeStore = companionManager.dexterRuntimeUIStateStore
        let runtimeState = runtimeStore.currentState
        let voiceState = companionManager.voiceInteractionState
        let profileName = companionManager.dexterProfileStore.activeProfile?.name ?? "Dexter"
        let statusDetail = humanReadableDetail(
            runtimeDetail: runtimeStore.statusDetail,
            ambientState: nil
        )

        let isExecuting = isActivelyExecuting(
            runtimeState: runtimeState,
            voiceState: voiceState
        )

        if let confirmation = companionManager.actionConfirmationPresentation {
            return DexterAmbientResolvedState(
                ambientState: .permission,
                statusTitle: "Permission needed",
                statusDetail: confirmation.content.whatWillHappen,
                characterState: .working,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: notchRecommendation
            )
        }

        if notchRecommendation?.kind == .permissionRequest {
            return DexterAmbientResolvedState(
                ambientState: .permission,
                statusTitle: notchRecommendation?.headline ?? "Permission needed",
                statusDetail: notchRecommendation?.body ?? statusDetail,
                characterState: .working,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: notchRecommendation
            )
        }

        if ephemeralSuccessActive, !isExecuting {
            return DexterAmbientResolvedState(
                ambientState: .success,
                statusTitle: "Done",
                statusDetail: notchRecommendation?.body ?? "Step completed",
                characterState: .success,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: notchRecommendation
            )
        }

        if notchRecommendation?.kind == .agentCompletion, !isExecuting {
            return DexterAmbientResolvedState(
                ambientState: .success,
                statusTitle: "Done",
                statusDetail: notchRecommendation?.body ?? "",
                characterState: .success,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: notchRecommendation
            )
        }

        let hasFailure = runtimeStore.failurePresentation != nil
            || runtimeState == .failed
            || voiceState == .error
            || notchRecommendation?.kind == .agentFailure

        if hasFailure, !isExecuting {
            let failureDetail = runtimeStore.failurePresentation?.whatYouCanDoNext
                ?? notchRecommendation?.body
                ?? "Try again or open Dexter for details."
            return DexterAmbientResolvedState(
                ambientState: .error,
                statusTitle: "Something went wrong",
                statusDetail: failureDetail,
                characterState: .error,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: notchRecommendation
            )
        }

        if runtimeState == .acting || runtimeState == .planning {
            var detail = humanReadableDetail(runtimeDetail: runtimeStore.statusDetail, ambientState: .working)
            if !DexterProductCapabilityRegistry.isCapabilityUsable(.computerControl, in: productCapabilities),
               detail.isEmpty {
                detail = "Computer control unavailable. Open Dexter to reconnect the runtime."
            }
            return DexterAmbientResolvedState(
                ambientState: .working,
                statusTitle: "Working…",
                statusDetail: detail,
                characterState: .working,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: nil
            )
        }

        if runtimeState == .verifying {
            let detail = humanReadableDetail(runtimeDetail: runtimeStore.statusDetail, ambientState: .working)
            return DexterAmbientResolvedState(
                ambientState: .working,
                statusTitle: "Checking result…",
                statusDetail: detail,
                characterState: .working,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: nil
            )
        }

        if companionManager.isAssistantAudioSpeaking || voiceState == .speaking {
            return DexterAmbientResolvedState(
                ambientState: .speaking,
                statusTitle: "Speaking…",
                statusDetail: "Dexter is responding out loud",
                characterState: .speaking,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: nil
            )
        }

        if voiceState == .listening || voiceState == .transcribing || runtimeState == .listening {
            return DexterAmbientResolvedState(
                ambientState: .listening,
                statusTitle: "Listening…",
                statusDetail: "Hold to talk or release when finished",
                characterState: .listening,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: nil
            )
        }

        if voiceState == .thinking
            || runtimeState == .thinking
            || runtimeState == .understanding {
            let detail = humanReadableDetail(runtimeDetail: runtimeStore.statusDetail, ambientState: .thinking)
            return DexterAmbientResolvedState(
                ambientState: .thinking,
                statusTitle: "Thinking…",
                statusDetail: detail.isEmpty ? "Working on your request" : detail,
                characterState: .thinking,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: nil
            )
        }

        if let phase5Suggestion, shouldShowPhase5Suggestion(notchRecommendation: notchRecommendation) {
            return DexterAmbientResolvedState(
                ambientState: .suggestion,
                statusTitle: phase5Suggestion.title,
                statusDetail: phase5Suggestion.subtitle,
                characterState: .idle,
                activeProfileName: profileName,
                phase5Suggestion: phase5Suggestion,
                notchRecommendation: notchRecommendation
            )
        }

        if let notchRecommendation,
           notchRecommendation.priority >= .medium,
           notchRecommendation.kind != .dexterStatus {
            return DexterAmbientResolvedState(
                ambientState: .suggestion,
                statusTitle: notchRecommendation.headline,
                statusDetail: notchRecommendation.body,
                characterState: .idle,
                activeProfileName: profileName,
                phase5Suggestion: nil,
                notchRecommendation: notchRecommendation
            )
        }

        return DexterAmbientResolvedState(
            ambientState: .idle,
            statusTitle: "Ready",
            statusDetail: "Ask Dexter",
            characterState: .idle,
            activeProfileName: profileName,
            phase5Suggestion: nil,
            notchRecommendation: notchRecommendation
        )
    }

    private static func isActivelyExecuting(
        runtimeState: DexterRuntimeUIState,
        voiceState: DexterVoiceInteractionState
    ) -> Bool {
        switch runtimeState {
        case .acting, .verifying, .planning, .waitingPermission, .thinking, .understanding, .listening:
            return true
        default:
            break
        }
        switch voiceState {
        case .listening, .transcribing, .thinking, .speaking:
            return true
        case .idle, .error:
            break
        }
        return false
    }

    private static func shouldShowPhase5Suggestion(notchRecommendation: DexterNotchRecommendation?) -> Bool {
        guard let notchRecommendation else { return true }
        return notchRecommendation.priority < .high && notchRecommendation.kind == .dexterStatus
    }

    private static func humanReadableDetail(runtimeDetail: String, ambientState: DexterAmbientState?) -> String {
        let trimmed = runtimeDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lowered = trimmed.lowercased()
        if lowered.contains("openclaw") || lowered.contains("computer.act") || lowered.contains("node invoke") {
            return ambientState == .working ? "Working on your request" : ""
        }
        return trimmed
    }
}
