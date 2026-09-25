//
//  DexterPersonalizationService.swift
//  leanring-buddy
//

import Foundation

/// Resolves scoped memories and preference hints for model context — does not own storage.
enum DexterPersonalizationService {
    static let defaultRetrievalLimit = 6

    static func relevantMemories(
        query: String,
        from allMemories: [DexterStructuredMemoryRecord],
        retrievalContext: DexterMemoryRetrievalContext,
        limit: Int = defaultRetrievalLimit
    ) -> [DexterStructuredMemoryRecord] {
        let scoped = DexterMemoryScopeFilter.memoriesVisible(
            to: retrievalContext,
            from: allMemories
        )
        return DexterMemoryRetrievalEngine.retrieve(
            query: query,
            from: scoped,
            limit: limit
        )
    }

    static func explanationStyleHint(from memories: [DexterStructuredMemoryRecord]) -> String? {
        let preferenceMemories = memories.filter { $0.type == .preference && $0.status == .active }
        for memory in preferenceMemories {
            let normalized = memory.content.lowercased()
            if normalized.contains("concise") || normalized.contains("brief") || normalized.contains("short") {
                return "Prefer concise, direct answers unless the user asks for more detail."
            }
            if normalized.contains("detailed") || normalized.contains("thorough") {
                return "Prefer detailed explanations with clear structure."
            }
            if normalized.contains("eli5") || normalized.contains("simple language") {
                return "Explain in simple language with minimal jargon."
            }
        }
        return nil
    }
}

enum DexterMemoryScopeFilter {
    static func memoriesVisible(
        to retrievalContext: DexterMemoryRetrievalContext,
        from memories: [DexterStructuredMemoryRecord]
    ) -> [DexterStructuredMemoryRecord] {
        memories.filter { memory in
            isVisible(memory: memory, retrievalContext: retrievalContext)
        }
    }

    static func isVisible(
        memory: DexterStructuredMemoryRecord,
        retrievalContext: DexterMemoryRetrievalContext
    ) -> Bool {
        switch memory.scope {
        case .global:
            return true
        case .dexterProfile:
            guard let boundProfileId = memory.dexterProfileId else { return false }
            return boundProfileId == retrievalContext.activeDexterProfileId
        case .workspace:
            guard let boundProfileId = memory.dexterProfileId,
                  let boundWorkspaceId = memory.fileWorkspaceId else {
                return false
            }
            return boundProfileId == retrievalContext.activeDexterProfileId
                && boundWorkspaceId == retrievalContext.activeFileWorkspaceId
        }
    }
}
