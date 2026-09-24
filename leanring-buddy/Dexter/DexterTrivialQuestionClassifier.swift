//
//  DexterTrivialQuestionClassifier.swift
//  leanring-buddy
//

import Foundation

enum DexterTrivialQuestionClassifier {
    static func isTrivialQuestion(_ userMessage: String) -> Bool {
        let trimmedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return false }

        let normalized = trimmedMessage.lowercased()
        if DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: trimmedMessage) {
            return false
        }
        if normalized.contains("remember") || normalized.contains("forget") {
            return false
        }
        if DexterWorkspaceIntentRecognizer.recognizeSave(fromUserMessage: trimmedMessage)
            || DexterWorkspaceIntentRecognizer.recognizeRestore(fromUserMessage: trimmedMessage) {
            return false
        }
        if DexterActionRecoveryIntentRecognizer.recognizeUndo(fromUserMessage: trimmedMessage) {
            return false
        }

        let wordCount = normalized.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount > 14 {
            return false
        }

        let nonTrivialSignals = [
            "workflow", "assignment", "open ", "click", "fix it", "remember",
            "automate", "deploy", "debug", "error", "stack trace", "step by step"
        ]
        if nonTrivialSignals.contains(where: { normalized.contains($0) }) {
            return false
        }

        let trivialPatterns = [
            "what is", "what's", "who is", "define ", "explain ", "how do i",
            "thanks", "thank you", "hello", "hi dexter"
        ]
        return trivialPatterns.contains { normalized.hasPrefix($0) || normalized == $0 }
            || wordCount <= 6
    }
}
