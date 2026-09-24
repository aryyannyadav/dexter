//
//  DexterAccountabilityIntentRecognizer.swift
//  leanring-buddy
//

import Foundation

enum DexterAccountabilityQueryKind: Equatable {
    case whatAmIWorkingOn
    case whatsNext
    case whatDidILeaveUnfinished
    case continueMyWork
}

enum DexterAccountabilityIntentRecognizer {
    static func recognizeQuery(fromUserMessage userMessage: String) -> DexterAccountabilityQueryKind? {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if matchesAny(normalized, phrases: [
            "what am i working on",
            "what i'm working on",
            "what im working on"
        ]) {
            return .whatAmIWorkingOn
        }

        if matchesAny(normalized, phrases: [
            "what's next",
            "whats next",
            "what is next",
            "what do i do next"
        ]) {
            return .whatsNext
        }

        if matchesAny(normalized, phrases: [
            "what did i leave unfinished",
            "what's unfinished",
            "whats unfinished",
            "unfinished tasks",
            "what did i not finish"
        ]) {
            return .whatDidILeaveUnfinished
        }

        if matchesAny(normalized, phrases: [
            "continue my work",
            "resume my work",
            "pick up my work"
        ]) {
            return .continueMyWork
        }

        return nil
    }

    static func extractReminderRequest(fromUserMessage userMessage: String) -> String? {
        let normalized = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()

        let prefixes = [
            "remind me to ",
            "remind me about ",
            "remind me "
        ]

        for prefix in prefixes {
            if lowercased.hasPrefix(prefix) {
                let remainder = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty {
                    return remainder
                }
            }
        }

        if lowercased == "remind me" {
            return nil
        }

        return nil
    }

    static func extractStructuredTaskDeclaration(fromUserMessage userMessage: String) -> String? {
        let normalized = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        let prefixes = [
            "my current task is ",
            "my task is ",
            "i am working on ",
            "i'm working on "
        ]
        for prefix in prefixes {
            if lowercased.hasPrefix(prefix) {
                let remainder = String(normalized.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return remainder.isEmpty ? nil : remainder
            }
        }
        return nil
    }

    private static func matchesAny(_ normalized: String, phrases: [String]) -> Bool {
        phrases.contains { normalized.contains($0) }
    }
}
