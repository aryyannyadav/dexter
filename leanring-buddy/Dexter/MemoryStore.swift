//
//  MemoryStore.swift
//  leanring-buddy
//

import Foundation

/// One user/assistant exchange within a session (not persisted across app launches).
struct DexterConversationExchange: Equatable {
    let userTranscript: String
    let assistantResponse: String
}

/// Unified memory surface for Dexter. Implementations can later swap in cloud-backed storage.
protocol MemoryStore: AnyObject {
    // Session conversation (bounded, in-memory for the running app session).
    func appendExchange(userTranscript: String, assistantResponse: String)
    func recentExchanges(limit: Int) -> [DexterConversationExchange]
    func clearSessionMemory()
    var sessionExchangeCount: Int { get }

    // Explicit persistent memory (user-initiated or required workflow state).
    func rememberFact(_ content: String, title: String?, provenance: DexterMemoryProvenance)
    func saveUserPreference(title: String, content: String, provenance: DexterMemoryProvenance)
    func setActiveTask(description: String?, provenance: DexterMemoryProvenance)
    func setWorkflowContext(_ workflowContext: DexterWorkflowContextState?, provenance: DexterMemoryProvenance)

    var activeTaskDescription: String? { get }
    var workflowContext: DexterWorkflowContextState? { get }

    func allPersistentEntries() -> [DexterMemoryEntry]
    func persistentMemoryContext() -> DexterPersistentMemoryContext
    func removePersistentEntry(id: UUID)
    func clearPersistentMemory(kind: DexterMemoryEntryKind?)
    func clearWorkflowContext()
}

/// In-memory session history with a bounded number of exchanges.
final class SessionMemoryStore {
    private let maxSessionExchanges: Int
    private var exchanges: [DexterConversationExchange] = []

    init(maxSessionExchanges: Int = 10) {
        self.maxSessionExchanges = max(1, maxSessionExchanges)
    }

    var exchangeCount: Int {
        exchanges.count
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

/// Default composition used by the app: session conversation + on-disk persistent memory.
final class DefaultMemoryStore: MemoryStore {
    private let sessionMemoryStore: SessionMemoryStore
    private let persistentMemoryStore: PersistentMemoryStore

    init(maxSessionExchanges: Int = 10, persistentStorageURL: URL? = PersistentMemoryStore.defaultStorageURL()) {
        sessionMemoryStore = SessionMemoryStore(maxSessionExchanges: maxSessionExchanges)
        persistentMemoryStore = PersistentMemoryStore(storageURL: persistentStorageURL)
    }

    static func inMemoryForTesting(maxSessionExchanges: Int = 10) -> DefaultMemoryStore {
        DefaultMemoryStore(maxSessionExchanges: maxSessionExchanges, persistentStorageURL: nil)
    }

    var sessionExchangeCount: Int {
        sessionMemoryStore.exchangeCount
    }

    func appendExchange(userTranscript: String, assistantResponse: String) {
        sessionMemoryStore.appendExchange(userTranscript: userTranscript, assistantResponse: assistantResponse)
    }

    func recentExchanges(limit: Int) -> [DexterConversationExchange] {
        sessionMemoryStore.recentExchanges(limit: limit)
    }

    func clearSessionMemory() {
        sessionMemoryStore.clearSessionMemory()
    }

    func rememberFact(_ content: String, title: String?, provenance: DexterMemoryProvenance) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let resolvedTitle = (title ?? Self.defaultTitle(forFact: trimmedContent)).trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = DexterMemoryEntry(
            kind: .rememberedFact,
            title: resolvedTitle.isEmpty ? "Remembered fact" : resolvedTitle,
            content: trimmedContent,
            provenance: provenance
        )
        persistentMemoryStore.appendEntry(entry)
    }

    func saveUserPreference(title: String, content: String, provenance: DexterMemoryProvenance) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let entry = DexterMemoryEntry(
            kind: .userPreference,
            title: trimmedTitle.isEmpty ? "Preference" : trimmedTitle,
            content: trimmedContent,
            provenance: provenance
        )
        persistentMemoryStore.appendEntry(entry)
    }

    func setActiveTask(description: String?, provenance: DexterMemoryProvenance) {
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDescription, !trimmedDescription.isEmpty {
            persistentMemoryStore.activeTaskDescription = trimmedDescription
        } else {
            persistentMemoryStore.clearActiveTask()
        }
        _ = provenance
    }

    func setWorkflowContext(_ workflowContext: DexterWorkflowContextState?, provenance: DexterMemoryProvenance) {
        if let workflowContext {
            let trimmedSummary = workflowContext.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSummary.isEmpty else {
                persistentMemoryStore.clearWorkflowContext()
                return
            }
            persistentMemoryStore.workflowContext = DexterWorkflowContextState(
                summary: trimmedSummary,
                updatedAt: workflowContext.updatedAt
            )
        } else {
            persistentMemoryStore.clearWorkflowContext()
        }
        _ = provenance
    }

    var activeTaskDescription: String? {
        persistentMemoryStore.activeTaskDescription
    }

    var workflowContext: DexterWorkflowContextState? {
        persistentMemoryStore.workflowContext
    }

    func allPersistentEntries() -> [DexterMemoryEntry] {
        persistentMemoryStore.allEntries()
    }

    func persistentMemoryContext() -> DexterPersistentMemoryContext {
        DexterPersistentMemoryContext(
            userPreferences: persistentMemoryStore.entries(kind: .userPreference),
            rememberedFacts: persistentMemoryStore.entries(kind: .rememberedFact),
            workflowContext: persistentMemoryStore.workflowContext
        )
    }

    func removePersistentEntry(id: UUID) {
        persistentMemoryStore.removeEntry(id: id)
    }

    func clearPersistentMemory(kind: DexterMemoryEntryKind?) {
        persistentMemoryStore.clearEntries(kind: kind)
    }

    func clearWorkflowContext() {
        persistentMemoryStore.clearWorkflowContext()
    }

    private static func defaultTitle(forFact content: String) -> String {
        if content.count <= 48 {
            return content
        }
        return String(content.prefix(45)) + "..."
    }
}
