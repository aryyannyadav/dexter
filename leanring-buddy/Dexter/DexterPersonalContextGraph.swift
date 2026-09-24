//
//  DexterPersonalContextGraph.swift
//  leanring-buddy
//
//  Facade over the in-memory personal context graph (backed by MemoryStore + authorized context).
//

import Foundation

enum DexterPersonalContextGraph {
    static func buildSnapshot(
        memoryStore: MemoryStore,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterPersonalContextGraphSnapshot {
        DexterPersonalContextGraphBuilder.build(
            memoryStore: memoryStore,
            authorizedInput: authorizedInput
        )
    }

    static func tryRespondToPersonalContextQuery(
        userMessage: String,
        memoryStore: MemoryStore,
        lastAuthorizedContext: DexterContext?
    ) -> String? {
        guard let queryKind = DexterPersonalContextIntentRecognizer.recognize(fromUserMessage: userMessage) else {
            return nil
        }

        let authorizedInput: DexterAuthorizedPersonalContextInput
        if let lastAuthorizedContext {
            authorizedInput = .fromDexterContext(lastAuthorizedContext)
        } else {
            authorizedInput = .memoryOnly(memoryStore: memoryStore, userMessage: userMessage)
        }

        let graph = buildSnapshot(memoryStore: memoryStore, authorizedInput: authorizedInput)
        return DexterPersonalContextQueryEngine.respond(
            queryKind: queryKind,
            graph: graph,
            authorizedInput: authorizedInput
        )
    }

    /// Legacy helper used by older call sites.
    static func entities(from memoryStore: MemoryStore) -> [DexterContextGraphEntity] {
        buildSnapshot(
            memoryStore: memoryStore,
            authorizedInput: .memoryOnly(memoryStore: memoryStore, userMessage: "")
        ).entities
    }
}
