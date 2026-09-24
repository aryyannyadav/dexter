//
//  DexterMemoryRetrievalEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterMemoryRetrievalEngine {
    static func retrieve(
        query: String,
        from memories: [DexterStructuredMemoryRecord],
        limit: Int
    ) -> [DexterStructuredMemoryRecord] {
        let activeMemories = filterActiveNonStale(memories)
        let deduped = resolveSupersessionConflicts(activeMemories)
        guard limit > 0 else { return [] }

        let normalizedQuery = normalize(query)
        if normalizedQuery.isEmpty {
            return deduped
                .filter { $0.permissions.mayIncludeInModelContext }
                .sorted { $0.importance > $1.importance }
                .prefix(limit)
                .map { $0 }
        }

        let scored = deduped
            .filter { $0.permissions.mayIncludeInModelContext }
            .map { memory in
                (memory, relevanceScore(memory: memory, normalizedQuery: normalizedQuery))
            }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.importance > rhs.0.importance
            }

        if scored.isEmpty {
            return deduped
                .filter { $0.permissions.mayIncludeInModelContext }
                .sorted { $0.importance > $1.importance }
                .prefix(min(2, limit))
                .map { $0 }
        }

        return scored.prefix(limit).map(\.0)
    }

    private static func filterActiveNonStale(_ memories: [DexterStructuredMemoryRecord]) -> [DexterStructuredMemoryRecord] {
        let now = Date()
        return memories.filter { memory in
            guard memory.status == .active else { return false }
            if let expiration = memory.expiration, expiration < now {
                return false
            }
            return true
        }
    }

    private static func resolveSupersessionConflicts(
        _ memories: [DexterStructuredMemoryRecord]
    ) -> [DexterStructuredMemoryRecord] {
        let supersededIdentifiers = Set(memories.compactMap(\.supersedes))
        return memories.filter { memory in
            !supersededIdentifiers.contains(memory.id)
        }
    }

    private static func relevanceScore(memory: DexterStructuredMemoryRecord, normalizedQuery: String) -> Double {
        let content = normalize(memory.content)
        let title = normalize(memory.title ?? "")
        let project = normalize(memory.project ?? "")

        let queryTokens = tokenize(normalizedQuery)
        guard !queryTokens.isEmpty else { return 0 }

        var score = 0.0
        for token in queryTokens {
            if content.contains(token) { score += 2.0 }
            if title.contains(token) { score += 1.5 }
            if project.contains(token) { score += 1.0 }
            if memory.type.rawValue.lowercased().contains(token) { score += 0.5 }
        }

        if normalizedQuery.contains("prefer") && memory.type == .preference {
            score += 1.0
        }
        if normalizedQuery.contains("task") && memory.type == .task {
            score += 1.0
        }
        if normalizedQuery.contains("project") && memory.type == .project {
            score += 1.0
        }

        score *= memory.confidence
        score += memory.importance * 0.25
        return score
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }
}
