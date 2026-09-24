//
//  DexterSpeechTextCleaner.swift
//  leanring-buddy
//

import Foundation

enum DexterSpeechTextCleaner {
    /// Converts assistant markdown-ish text into phrasing suitable for AVSpeechSynthesizer.
    static func spokenText(from assistantResponseText: String) -> String {
        var cleanedText = assistantResponseText

        cleanedText = removePointTags(from: cleanedText)
        cleanedText = removeFencedCodeBlocks(from: cleanedText)
        cleanedText = removeInlineCode(from: cleanedText)
        cleanedText = removeMarkdownLinks(from: cleanedText)
        cleanedText = removeMarkdownEmphasis(from: cleanedText)
        cleanedText = normalizeListAndHeadingMarkersForSpeech(from: cleanedText)
        cleanedText = collapseWhitespace(cleanedText)

        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeListAndHeadingMarkersForSpeech(from text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        lines = lines.map { line in
            var trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("#") {
                trimmedLine = trimmedLine.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            }
            trimmedLine = trimmedLine.replacingOccurrences(of: #"^[-*•]\s+"#, with: "", options: .regularExpression)
            trimmedLine = trimmedLine.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
            return trimmedLine
        }
        return lines.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    private static func removePointTags(from text: String) -> String {
        let pattern = #"\[POINT:[^\]]+\]\s*$"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func removeFencedCodeBlocks(from text: String) -> String {
        let pattern = #"```[\s\S]*?```"#
        return text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    }

    private static func removeInlineCode(from text: String) -> String {
        text.replacingOccurrences(of: "`", with: "")
    }

    private static func removeMarkdownLinks(from text: String) -> String {
        let pattern = #"\[([^\]]+)\]\([^)]+\)"#
        return text.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
    }

    private static func removeMarkdownEmphasis(from text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
