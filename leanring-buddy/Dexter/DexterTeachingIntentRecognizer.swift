//
//  DexterTeachingIntentRecognizer.swift
//  leanring-buddy
//

import Foundation

enum DexterTeachingIntentRecognizer {
    static func recognizeResponseMode(forUserMessage userMessage: String) -> DexterResponseMode {
        let normalizedMessage = userMessage
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if matchesActIntent(normalizedMessage) {
            return .act
        }

        if matchesTroubleshootIntent(normalizedMessage) {
            return .troubleshoot
        }

        if matchesTeachIntent(normalizedMessage) {
            return .teach
        }

        if matchesGuideIntent(normalizedMessage) {
            return .guide
        }

        if matchesExplainIntent(normalizedMessage) {
            return .explain
        }

        if matchesHowIntent(normalizedMessage) {
            return .guide
        }

        return .answer
    }

    private static func matchesActIntent(_ normalizedMessage: String) -> Bool {
        if normalizedMessage.contains("how do") || normalizedMessage.contains("how to") || normalizedMessage.contains("how can") {
            return false
        }

        if normalizedMessage == "open safari"
            || normalizedMessage == "please open safari"
            || normalizedMessage == "open safari for me"
            || normalizedMessage == "open the safari app" {
            return true
        }

        if normalizedMessage == "fix it"
            || normalizedMessage == "fix it for me"
            || normalizedMessage == "apply the fix" {
            return true
        }

        if normalizedMessage.contains("open vscode")
            || normalizedMessage.contains("open vs code")
            || normalizedMessage.contains("open visual studio code") {
            return true
        }

        if DexterPointerControlWorkflow.matchesPointerActIntent(normalizedUserMessage: normalizedMessage) {
            return true
        }

        let actPhrases = [
            "click the",
            "click on",
            "press the",
            "open the",
            "do this for me",
            "do it for me",
            "run this",
            "execute",
            "take action",
            "perform"
        ]
        return actPhrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesTroubleshootIntent(_ normalizedMessage: String) -> Bool {
        let troubleshootPhrases = [
            "troubleshoot",
            "debug",
            "what went wrong",
            "what's wrong here",
            "whats wrong here",
            "why is this error",
            "why isn't this working",
            "why is this not working",
            "not working"
        ]
        if troubleshootPhrases.contains(where: { normalizedMessage.contains($0) }) {
            return true
        }

        let hasErrorSignal = normalizedMessage.contains("error")
            || normalizedMessage.contains("exception")
            || normalizedMessage.contains("failed")
            || normalizedMessage.contains("crash")
        let hasWhy = normalizedMessage.contains("why ")
        return hasErrorSignal && hasWhy
    }

    private static func matchesTeachIntent(_ normalizedMessage: String) -> Bool {
        let teachPhrases = [
            "teach me",
            "help me learn",
            "i want to learn",
            "walk me through learning"
        ]
        return teachPhrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesGuideIntent(_ normalizedMessage: String) -> Bool {
        let guidePhrases = [
            "guide me",
            "step by step",
            "walk me through",
            "show me how",
            "how do i",
            "how to "
        ]
        return guidePhrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesExplainIntent(_ normalizedMessage: String) -> Bool {
        if DexterPointerControlWorkflow.matchesPointerExplainIntent(normalizedMessage) {
            return true
        }

        let explainPhrases = [
            "explain",
            "what does",
            "what is",
            "what's",
            "why does",
            "why is",
            "why are",
            "tell me why"
        ]
        return explainPhrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesHowIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("how ")
    }
}
