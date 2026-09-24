//
//  DexterPersonalContextIntentRecognizer.swift
//  leanring-buddy
//

import Foundation

enum DexterPersonalContextIntentRecognizer {
    static func recognize(fromUserMessage userMessage: String) -> DexterPersonalContextQueryKind? {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if matchesAny(normalized, phrases: [
            "where was i",
            "where were we",
            "what app was i in"
        ]) {
            return .whereWasI
        }

        if matchesAny(normalized, phrases: [
            "what was i doing",
            "what were we doing",
            "what am i working on"
        ]) {
            return .whatWasIDoing
        }

        if matchesAny(normalized, phrases: [
            "continue where we left off",
            "pick up where we left off",
            "resume where we left off",
            "continue where i left off"
        ]) {
            return .continueWhereLeftOff
        }

        if matchesAny(normalized, phrases: [
            "catch me up",
            "fill me in",
            "brief me"
        ]) {
            return .catchMeUp
        }

        if matchesAny(normalized, phrases: [
            "what should i do next",
            "what's next",
            "whats next",
            "what do i do next"
        ]) {
            return .whatShouldIDoNext
        }

        return nil
    }

    static func isPersonalContextQuery(_ userMessage: String) -> Bool {
        recognize(fromUserMessage: userMessage) != nil
    }

    private static func matchesAny(_ normalized: String, phrases: [String]) -> Bool {
        phrases.contains { normalized.contains($0) }
    }
}
