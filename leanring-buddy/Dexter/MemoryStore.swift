//
//  MemoryStore.swift
//  leanring-buddy
//

import Foundation

/// One user/assistant exchange within a session.
struct DexterConversationExchange: Equatable {
    let userTranscript: String
    let assistantResponse: String
}

/// Session-scoped memory (conversation history). Persistent memory is a future layer.
protocol MemoryStore: AnyObject {
    func appendExchange(userTranscript: String, assistantResponse: String)
    func recentExchanges(limit: Int) -> [DexterConversationExchange]
    func clearSessionMemory()
}

/// In-memory session history with a bounded number of exchanges.
final class SessionMemoryStore: MemoryStore {
    private let maxSessionExchanges: Int
    private var exchanges: [DexterConversationExchange] = []

    init(maxSessionExchanges: Int = 10) {
        self.maxSessionExchanges = max(1, maxSessionExchanges)
    }

    func appendExchange(userTranscript: String, assistantResponse: String) {
        exchanges.append(DexterConversationExchange(
            userTranscript: userTranscript,
            assistantResponse: assistantResponse
        ))
        if exchanges.count > maxSessionExchanges {
            exchanges.removeFirst(exchanges.count - maxSessionExchanges)
        }
    }

    func recentExchanges(limit: Int) -> [DexterConversationExchange] {
        guard limit > 0 else { return [] }
        if exchanges.count <= limit {
            return exchanges
        }
        return Array(exchanges.suffix(limit))
    }

    func clearSessionMemory() {
        exchanges.removeAll()
    }
}
