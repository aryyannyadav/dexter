//
//  DexterFileWorkspaceSearch.swift
//  leanring-buddy
//
//  Local workspace search over indexed metadata (no cloud upload).
//

import Foundation

enum DexterFileWorkspaceSearch {
    struct Query: Equatable {
        var text: String
        var maxResults: Int
    }

    static func search(snapshot: DexterFileWorkspaceIndexSnapshot?, query: Query) -> [DexterFileContext] {
        guard let snapshot else { return [] }
        let normalized = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        let tokens = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let scored = snapshot.files.compactMap { file -> (DexterFileContext, Int)? in
            var score = 0
            let haystack = (file.name + " " + file.displayPath + " " + (file.searchableTextSnippet ?? "")).lowercased()
            for token in tokens where haystack.contains(token) {
                score += 1
            }
            return score > 0 ? (file, score) : nil
        }
        .sorted { $0.1 > $1.1 }
        .prefix(query.maxResults)
        .map(\.0)

        return Array(scored)
    }
}
