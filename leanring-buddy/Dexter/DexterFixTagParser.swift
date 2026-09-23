//
//  DexterFixTagParser.swift
//  leanring-buddy
//

import Foundation

enum DexterFixTagParser {
    private static let fixTagPattern = #"\[DEXTER_FIX:([^\]]+)\]"#

    static func extractFixText(from assistantResponse: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: fixTagPattern, options: []) else {
            return nil
        }
        let range = NSRange(assistantResponse.startIndex..<assistantResponse.endIndex, in: assistantResponse)
        guard let match = regex.firstMatch(in: assistantResponse, options: [], range: range),
              match.numberOfRanges > 1,
              let fixRange = Range(match.range(at: 1), in: assistantResponse) else {
            return nil
        }
        let fixText = String(assistantResponse[fixRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return fixText.isEmpty ? nil : fixText
    }

    static func spokenText(removingFixTagFrom assistantResponse: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: fixTagPattern, options: []) else {
            return assistantResponse
        }
        let range = NSRange(assistantResponse.startIndex..<assistantResponse.endIndex, in: assistantResponse)
        let stripped = regex.stringByReplacingMatches(in: assistantResponse, options: [], range: range, withTemplate: "")
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class DexterDemonstrationSessionStore {
    private(set) var pendingCodeFixText: String?

    func recordProposedFix(fromAssistantResponse assistantResponse: String) {
        pendingCodeFixText = DexterFixTagParser.extractFixText(from: assistantResponse)
    }

    func consumePendingCodeFixText() -> String? {
        let fixText = pendingCodeFixText
        pendingCodeFixText = nil
        return fixText
    }

    var hasPendingCodeFix: Bool {
        guard let pendingCodeFixText else { return false }
        return !pendingCodeFixText.isEmpty
    }
}
