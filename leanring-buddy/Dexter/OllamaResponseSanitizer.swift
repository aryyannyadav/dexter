//
//  OllamaResponseSanitizer.swift
//  leanring-buddy
//

import Foundation

enum OllamaResponseSanitizer {
    private static let thinkTagPattern: String = {
        let openTag = "<" + "think" + ">"
        let closeTag = "</" + "think" + ">"
        return "(?s)" + openTag + ".*?" + closeTag
    }()

    private static let redactedThinkingPattern = "(?s)<think>.*?</think>"

    /// Sanitizes a single Ollama stream delta without trimming edges.
    /// Trimming each chunk drops whitespace-only tokens and removes spaces between streamed words.
    static func userFacingAssistantStreamDelta(content: String, separateThinkingField: String?) -> String {
        _ = separateThinkingField
        return stripKnownThinkingMarkers(from: content)
    }

    /// Returns user-visible assistant text only — never chain-of-thought / thinking fields.
    static func userFacingAssistantText(content: String, separateThinkingField: String?) -> String {
        userFacingAssistantStreamDelta(content: content, separateThinkingField: separateThinkingField)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripKnownThinkingMarkers(from text: String) -> String {
        var result = text
        for pattern in [thinkTagPattern, redactedThinkingPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result
    }
}
