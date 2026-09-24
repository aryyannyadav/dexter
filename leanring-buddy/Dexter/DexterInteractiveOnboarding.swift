//
//  DexterInteractiveOnboarding.swift
//  leanring-buddy
//
//  Experiential first-run flow: point → explain → safe action → verify → finale.
//

import Combine
import Foundation

enum DexterInteractiveOnboardingPhase: String, Equatable {
    case inactive = "INACTIVE"
    case awaitingPoint = "AWAITING_POINT"
    case awaitingExplainQuestion = "AWAITING_EXPLAIN_QUESTION"
    case awaitingActionRequest = "AWAITING_ACTION_REQUEST"
    case awaitingActionOutcome = "AWAITING_ACTION_OUTCOME"
    case finale = "FINALE"
    case completed = "COMPLETED"
}

enum DexterInteractiveOnboardingPolicy {
    static let finaleMessage =
        "I can understand your screen, teach you, and act when you ask."

    static let safeOnboardingActionSuggestion = "Open Calculator"

    static func shouldAutoApproveOnboardingAction(action: DexterAction) -> Bool {
        guard action.type == .openApplication else { return false }
        let applicationName = action.parameters["applicationName"]?.lowercased() ?? ""
        let allowedNames = ["calculator", "safari", "textedit"]
        return allowedNames.contains(applicationName)
    }

    static func isLikelyExplainUtterance(_ transcript: String) -> Bool {
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        let explainPhrases = [
            "what is this",
            "what's this",
            "what is that",
            "what's that",
            "explain this",
            "tell me about this",
            "describe this"
        ]
        return explainPhrases.contains { normalized.contains($0) } || normalized.count >= 4
    }

    static func isLikelyActionUtterance(_ transcript: String) -> Bool {
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let actionPrefixes = ["open ", "launch ", "start ", "focus "]
        return actionPrefixes.contains { normalized.hasPrefix($0) }
    }
}

@MainActor
final class DexterInteractiveOnboardingStore: ObservableObject {
    @Published private(set) var phase: DexterInteractiveOnboardingPhase = .inactive
    @Published private(set) var overlayPrompt: String = ""
    @Published private(set) var panelHeadline: String = ""
    @Published private(set) var panelDetail: String = ""

    var isActive: Bool {
        switch phase {
        case .inactive, .completed:
            return false
        default:
            return true
        }
    }

    func beginInteractiveOnboarding() {
        phase = .awaitingPoint
        applyPromptsForCurrentPhase()
    }

    func replayInteractiveOnboarding() {
        phase = .awaitingPoint
        applyPromptsForCurrentPhase()
    }

    func registerPointCaptureIfNeeded() {
        guard phase == .awaitingPoint else { return }
        phase = .awaitingExplainQuestion
        applyPromptsForCurrentPhase()
    }

    func registerExplainTurnCompletedIfNeeded() {
        guard phase == .awaitingExplainQuestion else { return }
        phase = .awaitingActionRequest
        applyPromptsForCurrentPhase()
    }

    func registerActionRequestStartedIfNeeded() {
        guard phase == .awaitingActionRequest else { return }
        phase = .awaitingActionOutcome
        applyPromptsForCurrentPhase()
    }

    func registerVerifiedActionCompletedIfNeeded() {
        guard phase == .awaitingActionOutcome else { return }
        phase = .finale
        applyPromptsForCurrentPhase()
    }

    func markCompleted() {
        phase = .completed
        overlayPrompt = ""
        panelHeadline = ""
        panelDetail = ""
    }

    func resetToInactive() {
        phase = .inactive
        overlayPrompt = ""
        panelHeadline = ""
        panelDetail = ""
    }

    private func applyPromptsForCurrentPhase() {
        switch phase {
        case .inactive, .completed:
            overlayPrompt = ""
            panelHeadline = ""
            panelDetail = ""
        case .awaitingPoint:
            overlayPrompt = "Point at anything."
            panelHeadline = "Step 1 — Point"
            panelDetail = "Press \(DexterPointInvokeShortcut.displayText) while your cursor is over something on screen."
        case .awaitingExplainQuestion:
            overlayPrompt = "Now ask me what it is."
            panelHeadline = "Step 2 — Ask"
            panelDetail = "Hold \(BuddyPushToTalkShortcut.ShortcutOption.controlOption.displayText) and ask what you're pointing at."
        case .awaitingActionRequest:
            overlayPrompt = "Now ask me to do something."
            panelHeadline = "Step 3 — Act"
            panelDetail = "Try: “\(DexterInteractiveOnboardingPolicy.safeOnboardingActionSuggestion).” Dexter will verify it worked."
        case .awaitingActionOutcome:
            overlayPrompt = "Working on it…"
            panelHeadline = "Step 3 — Act"
            panelDetail = "Dexter is running and checking the result."
        case .finale:
            overlayPrompt = DexterInteractiveOnboardingPolicy.finaleMessage
            panelHeadline = "You're set"
            panelDetail = DexterInteractiveOnboardingPolicy.finaleMessage
        }
    }
}
