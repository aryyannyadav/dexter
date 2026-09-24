//
//  DexterConversationPackaging.swift
//  leanring-buddy
//

import Foundation

struct DexterPackagedConversationContext: Equatable {
    let recentExchangesForPrompt: [DexterConversationExchange]
    let earlierSessionSummary: String?
    let recentExchangesForAPIHistory: [DexterConversationExchange]
}

enum DexterConversationPackaging {
    static let promptExchangeLimit = 2
    static let apiHistoryExchangeLimit = 4

    static func package(allExchanges: [DexterConversationExchange]) -> DexterPackagedConversationContext {
        let recentForAPI = Array(allExchanges.suffix(apiHistoryExchangeLimit))
        let recentForPrompt = Array(recentForAPI.suffix(promptExchangeLimit))
        let olderExchanges = Array(allExchanges.dropLast(recentForAPI.count))

        let summary = buildEarlierSessionSummary(from: olderExchanges)

        return DexterPackagedConversationContext(
            recentExchangesForPrompt: recentForPrompt,
            earlierSessionSummary: summary,
            recentExchangesForAPIHistory: recentForAPI
        )
    }

    static func buildEarlierSessionSummary(from exchanges: [DexterConversationExchange]) -> String? {
        guard !exchanges.isEmpty else { return nil }

        let topicSnippets = exchanges.suffix(6).map { exchange in
            let userSnippet = String(exchange.userTranscript.prefix(80))
            return userSnippet
        }

        let uniqueTopics = Array(Set(topicSnippets)).prefix(4)
        return "Earlier in this session (summary, not full transcript): "
            + uniqueTopics.joined(separator: "; ")
    }
}

enum DexterContextMemoryLimitPolicy {
    static func retrievalLimit(for request: DexterContextAssemblyRequest) -> Int {
        if request.performanceProfile == .minimal {
            return 2
        }
        if DexterTrivialQuestionClassifier.isTrivialQuestion(request.userMessage) {
            return 2
        }
        if DexterPersonalContextIntentRecognizer.isPersonalContextQuery(request.userMessage) {
            return 6
        }
        return 4
    }
}
