//
//  DexterSuggestionRankingFilter.swift
//  leanring-buddy
//

import Foundation

enum DexterSuggestionRankingFilter {
    static func rankedHomeSuggestions(
        contextSuggestions: [DexterSuggestion],
        profileWorkSuggestions: [DexterProfileWorkSuggestion],
        activeProfileId: UUID?,
        recentConversationTitles: [String],
        recentAcceptedPrompts: [String],
        evaluatedAt: Date
    ) -> [DexterHomeSuggestionItem] {
        let freshContext = contextSuggestions.filter { suggestion in
            !isExpired(suggestion, evaluatedAt: evaluatedAt)
        }

        var items: [DexterHomeSuggestionItem] = []
        items.append(contentsOf: freshContext.map { DexterHomeSuggestionItem.context($0) })

        let scopedWork = profileWorkSuggestions.filter { work in
            guard let activeProfileId else { return true }
            return work.dexterProfileId == activeProfileId
        }
        items.append(contentsOf: scopedWork.map { DexterHomeSuggestionItem.profileWork($0) })

        items = items.filter { item in
            !isDuplicateOfRecentActivity(item: item, recentTitles: recentConversationTitles, recentPrompts: recentAcceptedPrompts)
        }

        items = deduplicateByIntent(items)

        return items.sorted { $0.priority > $1.priority }
    }

    private static func isExpired(_ suggestion: DexterSuggestion, evaluatedAt: Date) -> Bool {
        if let expiresAt = suggestion.expiresAt, evaluatedAt > expiresAt {
            return true
        }
        return false
    }

    private static func isDuplicateOfRecentActivity(
        item: DexterHomeSuggestionItem,
        recentTitles: [String],
        recentPrompts: [String]
    ) -> Bool {
        let normalizedTitle = normalize(item.title)
        for recentTitle in recentTitles.prefix(3) {
            if normalize(recentTitle).contains(normalizedTitle) || normalizedTitle.contains(normalize(recentTitle)) {
                return true
            }
        }
        for prompt in recentPrompts.prefix(5) {
            if normalize(prompt).contains(normalizedTitle) {
                return true
            }
        }
        return false
    }

    private static func deduplicateByIntent(_ items: [DexterHomeSuggestionItem]) -> [DexterHomeSuggestionItem] {
        var seen: Set<String> = []
        var result: [DexterHomeSuggestionItem] = []
        for item in items {
            let key = normalize(item.title)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
        }
        return result
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: "")
    }
}
