//
//  DexterMemoryInferenceTracker.swift
//  leanring-buddy
//

import Foundation

/// Session-scoped behavior observation — never persisted until the user confirms.
final class DexterMemoryInferenceTracker {
    private var behaviorObservationCounts: [String: Int] = [:]
    private(set) var pendingSuggestion: DexterMemoryInferenceSuggestion?

    private let confirmationThreshold = 3

    func observeUserMessage(_ userMessage: String) {
        guard let behaviorKey = normalizedBehaviorKey(from: userMessage) else { return }
        let nextCount = (behaviorObservationCounts[behaviorKey] ?? 0) + 1
        behaviorObservationCounts[behaviorKey] = nextCount

        if nextCount >= confirmationThreshold, pendingSuggestion == nil {
            pendingSuggestion = DexterMemoryInferenceSuggestion(
                id: UUID(),
                suggestedContent: behaviorKey,
                suggestedType: .preference,
                observationCount: nextCount
            )
        }
    }

    func consumePendingSuggestion() -> DexterMemoryInferenceSuggestion? {
        let suggestion = pendingSuggestion
        pendingSuggestion = nil
        return suggestion
    }

    private func normalizedBehaviorKey(from userMessage: String) -> String? {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns: [(prefix: String, label: String)] = [
            ("open safari", "Usually opens Safari for browsing"),
            ("open visual studio code", "Usually opens Visual Studio Code for coding"),
            ("search for ", "Often searches the web for topics"),
        ]

        for pattern in patterns where normalized.hasPrefix(pattern.prefix) {
            return pattern.label
        }
        return nil
    }
}
