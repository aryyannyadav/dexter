//
//  DexterHubAmbientSummaryBuilder.swift
//  leanring-buddy
//
//  Generic one-line ambient summaries for Dexter Hub (no full response text).
//

import Foundation

enum DexterHubAmbientSummaryBuilder {
    static func build(from assistantResponse: String) -> (title: String, subtitle: String) {
        let cleaned = sanitizeForHub(assistantResponse)
        let sentences = splitSentences(from: cleaned)
        let subtitle = (sentences.first ?? cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedSubtitle = boundLength(subtitle, maxLength: 140)
        let title = inferTitle(from: cleaned, sentences: sentences)
        return (title, boundedSubtitle.isEmpty ? "Here's what I found." : boundedSubtitle)
    }

    private static func sanitizeForHub(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"\[POINT:[^\]]+\]"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\[DEXTER_FIX:[^\]]+\]"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "`", with: "")
        while result.contains("\n\n") {
            result = result.replacingOccurrences(of: "\n\n", with: "\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitSentences(from text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        let parts = normalized.split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" })
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func inferTitle(from cleaned: String, sentences: [String]) -> String {
        let lowercased = cleaned.lowercased()
        if lowercased.contains("fix") || lowercased.contains("problem") || lowercased.contains("error")
            || lowercased.contains("issue") || lowercased.contains("broken") {
            return "I found the problem."
        }
        if lowercased.contains("cause") || lowercased.contains("because") || lowercased.contains("setting") {
            return "I found the problem."
        }
        if sentences.count > 1 {
            return "Got it."
        }
        return "Here's what I found."
    }

    private static func boundLength(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
