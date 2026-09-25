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

/// Unified memory surface for Dexter.
protocol MemoryStore: AnyObject {
    func appendExchange(userTranscript: String, assistantResponse: String)
    func recentExchanges(limit: Int) -> [DexterConversationExchange]
    func clearSessionMemory()
    var sessionExchangeCount: Int { get }

    func rememberFact(_ content: String, title: String?, provenance: DexterMemoryProvenance)
    func saveUserPreference(title: String, content: String, provenance: DexterMemoryProvenance)
    func setActiveTask(description: String?, provenance: DexterMemoryProvenance)
    func setWorkflowContext(_ workflowContext: DexterWorkflowContextState?, provenance: DexterMemoryProvenance)

    var activeTaskDescription: String? { get }
    var workflowContext: DexterWorkflowContextState? { get }

    func allPersistentEntries() -> [DexterMemoryEntry]
    func allStructuredMemories() -> [DexterStructuredMemoryRecord]
    func persistentMemoryContext(forQuery query: String, limit: Int) -> DexterPersistentMemoryContext
    func persistentMemoryContext(
        forQuery query: String,
        limit: Int,
        retrievalContext: DexterMemoryRetrievalContext
    ) -> DexterPersistentMemoryContext
    func removePersistentEntry(id: UUID)
    func clearPersistentMemory(kind: DexterMemoryEntryKind?)
    func clearWorkflowContext()

    func saveInferredMemoryPendingConfirmation(content: String, type: DexterMemoryType)
    func processMemoryIntents(fromUserMessage userMessage: String) -> DexterMemoryIntentOutcome
    func observeUserMessageForInference(_ userMessage: String)
    func consumeInferenceConfirmationPrompt() -> String?
    func peekPendingInferenceSuggestion() -> DexterMemoryInferenceSuggestion?
    func confirmPendingInferenceSuggestion(binding: DexterMemoryBinding)
    func declinePendingInferenceSuggestion()
    func structuredMemories(forProfileId profileId: UUID) -> [DexterStructuredMemoryRecord]
    func updateStructuredMemoryContent(memoryId: UUID, newContent: String) -> Bool
    func clearStructuredMemories(forProfileId profileId: UUID)
    func replaceStructuredMemories(_ memories: [DexterStructuredMemoryRecord])
    func saveStructuredMemoryRecord(_ record: DexterStructuredMemoryRecord)

    var currentMemoryBinding: DexterMemoryBinding { get set }

    func accountabilityTaskSnapshot() -> DexterAccountabilityTaskSnapshot
    func allAccountabilityTasks() -> [DexterAccountabilityTask]
    func activeAccountabilityTask() -> DexterAccountabilityTask?
    func upsertAccountabilityTask(_ task: DexterAccountabilityTask)
    func setActiveAccountabilityTaskIdentifier(_ identifier: UUID?)
    func removeAccountabilityTask(identifier: UUID)
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

/// Default composition: session conversation + on-disk structured memory engine.
final class DefaultMemoryStore: MemoryStore {
    private let sessionMemoryStore: SessionMemoryStore
    private var persistentMemoryStore: PersistentMemoryStore
    private let accountabilityTaskStore: DexterAccountabilityTaskStore
    private let inferenceTracker = DexterMemoryInferenceTracker()
    var currentMemoryBinding: DexterMemoryBinding = .global
    weak var activityRecorder: DexterActivityRecorder?

    init(
        maxSessionExchanges: Int = 10,
        persistentStorageURL: URL? = PersistentMemoryStore.defaultStorageURL(),
        accountabilityTasksStorageURL: URL? = DexterAccountabilityTaskStore.defaultStorageURL()
    ) {
        sessionMemoryStore = SessionMemoryStore(maxSessionExchanges: maxSessionExchanges)
        persistentMemoryStore = PersistentMemoryStore(storageURL: persistentStorageURL)
        accountabilityTaskStore = DexterAccountabilityTaskStore(storageURL: accountabilityTasksStorageURL)
    }

    static func inMemoryForTesting(maxSessionExchanges: Int = 10) -> DefaultMemoryStore {
        DefaultMemoryStore(
            maxSessionExchanges: maxSessionExchanges,
            persistentStorageURL: nil,
            accountabilityTasksStorageURL: nil
        )
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
        let record = DexterStructuredMemoryRecord.explicitSemantic(
            content: trimmedContent,
            title: resolvedTitle.isEmpty ? "Remembered fact" : resolvedTitle,
            type: .semantic,
            binding: currentMemoryBinding
        )
        _ = saveStructuredRecord(record)
        _ = provenance
    }

    func saveUserPreference(title: String, content: String, provenance: DexterMemoryProvenance) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let record = DexterStructuredMemoryRecord.explicitPreference(
            content: trimmedContent,
            title: trimmedTitle.isEmpty ? "Preference" : trimmedTitle,
            binding: currentMemoryBinding
        )
        _ = saveStructuredRecord(record)
        _ = provenance
    }

    func setActiveTask(description: String?, provenance: DexterMemoryProvenance) {
        let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDescription, !trimmedDescription.isEmpty {
            persistentMemoryStore.activeTaskDescription = trimmedDescription
            let taskRecord = DexterStructuredMemoryRecord(
                type: .task,
                content: trimmedDescription,
                source: .explicitUserUtterance,
                confidence: 0.95,
                importance: 0.9,
                permissions: .defaultForExplicitUser,
                title: "Current task"
            )
            _ = saveStructuredRecord(taskRecord)
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
            let workflowRecord = DexterStructuredMemoryRecord(
                type: .workflow,
                content: trimmedSummary,
                source: .workflowSystem,
                confidence: 1.0,
                importance: 0.85,
                permissions: .defaultForExplicitUser,
                title: "Workflow"
            )
            _ = saveStructuredRecord(workflowRecord)
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

    func allStructuredMemories() -> [DexterStructuredMemoryRecord] {
        persistentMemoryStore.allMemories()
    }

    func allPersistentEntries() -> [DexterMemoryEntry] {
        persistentMemoryStore.activeMemories().map { $0.legacyMemoryEntry() }
    }

    func persistentMemoryContext(forQuery query: String, limit: Int = 6) -> DexterPersistentMemoryContext {
        persistentMemoryContext(
            forQuery: query,
            limit: limit,
            retrievalContext: DexterMemoryRetrievalContext(
                activeDexterProfileId: currentMemoryBinding.dexterProfileId,
                activeFileWorkspaceId: currentMemoryBinding.fileWorkspaceId
            )
        )
    }

    func persistentMemoryContext(
        forQuery query: String,
        limit: Int,
        retrievalContext: DexterMemoryRetrievalContext
    ) -> DexterPersistentMemoryContext {
        let retrieved = DexterPersonalizationService.relevantMemories(
            query: query,
            from: persistentMemoryStore.allMemories(),
            retrievalContext: retrievalContext,
            limit: limit
        )
        return DexterPersistentMemoryContext(
            retrievedMemories: retrieved,
            workflowContext: persistentMemoryStore.workflowContext
        )
    }

    func structuredMemories(forProfileId profileId: UUID) -> [DexterStructuredMemoryRecord] {
        persistentMemoryStore.activeMemories().filter { memory in
            switch memory.scope {
            case .global:
                return true
            case .dexterProfile, .workspace:
                return memory.dexterProfileId == profileId
            }
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func updateStructuredMemoryContent(memoryId: UUID, newContent: String) -> Bool {
        var memories = persistentMemoryStore.allMemories()
        guard let index = memories.firstIndex(where: { $0.id == memoryId && $0.status == .active }) else {
            return false
        }
        let existing = memories[index]
        markSuperseded(existing.id, in: &memories)
        let updated = DexterStructuredMemoryRecord(
            type: existing.type,
            content: newContent.trimmingCharacters(in: .whitespacesAndNewlines),
            source: .explicitUserUtterance,
            confidence: 0.95,
            importance: existing.importance,
            project: existing.project,
            supersedes: existing.id,
            permissions: .defaultForExplicitUser,
            title: existing.title,
            scope: existing.scope,
            dexterProfileId: existing.dexterProfileId,
            fileWorkspaceId: existing.fileWorkspaceId
        )
        switch DexterMemoryContentPolicy.evaluateForStorage(updated.content, source: .explicitUserUtterance) {
        case .rejected:
            return false
        case .allowed:
            memories.append(updated)
            persistentMemoryStore.mutateMemories { storedMemories in
                storedMemories = memories
            }
            return true
        }
    }

    func clearStructuredMemories(forProfileId profileId: UUID) {
        persistentMemoryStore.mutateMemories { memories in
            for index in memories.indices {
                let memory = memories[index]
                guard memory.status == .active else { continue }
                if memory.scope == .global { continue }
                if memory.dexterProfileId == profileId {
                    memories[index] = memory.withStatus(.forgotten)
                }
            }
        }
    }

    func peekPendingInferenceSuggestion() -> DexterMemoryInferenceSuggestion? {
        inferenceTracker.pendingSuggestion
    }

    func confirmPendingInferenceSuggestion(binding: DexterMemoryBinding) {
        guard let suggestion = inferenceTracker.consumePendingSuggestion() else { return }
        let record = DexterStructuredMemoryRecord(
            type: suggestion.suggestedType,
            content: suggestion.suggestedContent,
            source: .userConfirmed,
            confidence: 0.9,
            importance: 0.75,
            permissions: .defaultForExplicitUser,
            title: "Preference",
            scope: binding.scope,
            dexterProfileId: binding.dexterProfileId,
            fileWorkspaceId: binding.fileWorkspaceId
        )
        _ = saveStructuredRecord(record)
    }

    func declinePendingInferenceSuggestion() {
        _ = inferenceTracker.consumePendingSuggestion()
    }

    func removePersistentEntry(id: UUID) {
        let existing = persistentMemoryStore.allMemories().first { $0.id == id && $0.status == .active }
        persistentMemoryStore.removeMemory(id: id)
        if let existing {
            activityRecorder?.recordMemoryForgotten(
                contentPreview: existing.content,
                memoryId: existing.id,
                dexterProfileId: existing.dexterProfileId
            )
        }
    }

    func clearPersistentMemory(kind: DexterMemoryEntryKind?) {
        if let kind {
            switch kind {
            case .userPreference:
                persistentMemoryStore.clearMemories(type: .preference)
            case .rememberedFact:
                persistentMemoryStore.clearMemories(type: .semantic)
            }
        } else {
            persistentMemoryStore.clearMemories(type: nil)
        }
    }

    func clearWorkflowContext() {
        persistentMemoryStore.clearWorkflowContext()
    }

    func saveInferredMemoryPendingConfirmation(content: String, type: DexterMemoryType) {
        let record = DexterStructuredMemoryRecord(
            type: type,
            content: content,
            source: .inferredObservation,
            confidence: 0.55,
            importance: 0.5,
            permissions: .inferredUntilConfirmed,
            title: "Observed pattern"
        )
        _ = saveStructuredRecord(record)
    }

    func processMemoryIntents(fromUserMessage userMessage: String) -> DexterMemoryIntentOutcome {
        let accountabilityOutcome = DexterAccountabilityIntentProcessor.process(
            fromUserMessage: userMessage,
            memoryStore: self
        )
        switch accountabilityOutcome {
        case .userFacingResponse, .inferenceConfirmationPrompt:
            return accountabilityOutcome
        case .appliedSilently, .noMemoryIntent:
            return DexterMemoryIntentProcessor.process(fromUserMessage: userMessage, memoryStore: self)
        }
    }

    func saveStructuredMemoryRecord(_ record: DexterStructuredMemoryRecord) {
        _ = saveStructuredRecord(record)
    }

    func accountabilityTaskSnapshot() -> DexterAccountabilityTaskSnapshot {
        accountabilityTaskStore.makeSnapshot()
    }

    func allAccountabilityTasks() -> [DexterAccountabilityTask] {
        accountabilityTaskStore.allTasks()
    }

    func activeAccountabilityTask() -> DexterAccountabilityTask? {
        accountabilityTaskStore.activeTask()
    }

    func upsertAccountabilityTask(_ task: DexterAccountabilityTask) {
        accountabilityTaskStore.upsertTask(task)
    }

    func setActiveAccountabilityTaskIdentifier(_ identifier: UUID?) {
        accountabilityTaskStore.setActiveTaskIdentifier(identifier)
    }

    func removeAccountabilityTask(identifier: UUID) {
        accountabilityTaskStore.removeTask(identifier: identifier)
    }

    func observeUserMessageForInference(_ userMessage: String) {
        inferenceTracker.observeUserMessage(userMessage)
    }

    func consumeInferenceConfirmationPrompt() -> String? {
        guard let suggestion = inferenceTracker.pendingSuggestion else {
            return nil
        }
        return "You often do “\(suggestion.suggestedContent)”. Remember this for \(bindingLabel(for: currentMemoryBinding))?"
    }

    private func bindingLabel(for binding: DexterMemoryBinding) -> String {
        switch binding.scope {
        case .global:
            return "all Dexters"
        case .dexterProfile, .workspace:
            return "this Dexter"
        }
    }

    private func markSuperseded(_ identifier: UUID, in store: inout [DexterStructuredMemoryRecord]) {
        for index in store.indices where store[index].id == identifier {
            store[index] = store[index].withStatus(.superseded)
        }
    }

    func replaceStructuredMemories(_ memories: [DexterStructuredMemoryRecord]) {
        persistentMemoryStore.mutateMemories { storedMemories in
            storedMemories = memories
        }
    }

    @discardableResult
    private func saveStructuredRecord(_ record: DexterStructuredMemoryRecord) -> Result<DexterStructuredMemoryRecord, DexterMemoryError> {
        var memories = persistentMemoryStore.allMemories()
        let result = DexterMemoryEngine.saveExplicit(record: record, in: &memories)
        if case .success(let savedRecord) = result {
            persistentMemoryStore.mutateMemories { storedMemories in
                storedMemories = memories
            }
            activityRecorder?.recordMemorySaved(savedRecord)
        }
        return result
    }

    private static func defaultTitle(forFact content: String) -> String {
        if content.count <= 48 {
            return content
        }
        return String(content.prefix(45)) + "..."
    }
}
