//
//  DexterHubRepeatedWorkPatternAnalyzer.swift
//
//  Detects simple repeated verified-action patterns from existing action history (session scope).
//

import Foundation

struct DexterHubWorkflowSuggestionPayload: Equatable {
    let routineDisplayName: String
    let patternSummary: String
    let trustPreview: String
    let routineRunSupported: Bool
    let catalogWorkflowIdentifier: String?
}

enum DexterHubRepeatedWorkPatternAnalyzer {
    static let minimumMatchingActionCount = 3
    static let recentActionWindow = 8

    static func detectSuggestion(from recentActions: [DexterRecordedAction]) -> DexterHubWorkflowSuggestionPayload? {
        let window = Array(recentActions.suffix(recentActionWindow))
        guard window.count >= minimumMatchingActionCount else { return nil }

        var countsByIdentifier: [String: Int] = [:]
        for recordedAction in window {
            let normalizedIdentifier = recordedAction.actionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedIdentifier.isEmpty else { continue }
            countsByIdentifier[normalizedIdentifier, default: 0] += 1
        }

        guard let dominantEntry = countsByIdentifier.max(by: { $0.value < $1.value }),
              dominantEntry.value >= minimumMatchingActionCount
        else {
            return nil
        }

        let matchingSummaries = window
            .filter { $0.actionIdentifier == dominantEntry.key }
            .map(\.summary)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let patternSummary = boundSummary(matchingSummaries.last ?? dominantEntry.key)
        let routineDisplayName = buildRoutineDisplayName(
            actionIdentifier: dominantEntry.key,
            summaries: matchingSummaries
        )
        let trustPreview = buildTrustPreview(
            actionIdentifier: dominantEntry.key,
            repeatCount: dominantEntry.value,
            latestSummary: patternSummary
        )

        return DexterHubWorkflowSuggestionPayload(
            routineDisplayName: routineDisplayName,
            patternSummary: patternSummary,
            trustPreview: trustPreview,
            routineRunSupported: false,
            catalogWorkflowIdentifier: nil
        )
    }

    private static func buildRoutineDisplayName(actionIdentifier: String, summaries: [String]) -> String {
        if let firstSummary = summaries.first {
            let trimmedSummary = firstSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedSummary.count >= 6, trimmedSummary.count <= 48 {
                return trimmedSummary
            }
        }
        let humanized = actionIdentifier
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !humanized.isEmpty else { return "Your repeated workflow" }
        return "Your \(humanized.capitalized) routine"
    }

    private static func buildTrustPreview(actionIdentifier: String, repeatCount: Int, latestSummary: String) -> String {
        "You've done this \(repeatCount) times recently (\(actionIdentifier)). Next time, Dexter would ask before each step — starting with: \(latestSummary)."
    }

    private static func boundSummary(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 100 else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 100)
        return String(trimmed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
