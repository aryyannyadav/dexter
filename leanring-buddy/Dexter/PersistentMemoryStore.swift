//
//  PersistentMemoryStore.swift
//  leanring-buddy
//

import Foundation

/// Disk-backed structured memory engine state.
final class PersistentMemoryStore {
    private struct PersistedDexterMemoryStateV2: Codable, Equatable {
        var version: Int
        var memories: [DexterStructuredMemoryRecord]
        var activeTaskDescription: String?
        var workflowContext: DexterWorkflowContextState?
    }

    private struct PersistedDexterMemoryStateV1: Codable, Equatable {
        var entries: [DexterMemoryEntry]
        var activeTaskDescription: String?
        var workflowContext: DexterWorkflowContextState?
    }

    private let storageURL: URL?
    private var state: PersistedDexterMemoryStateV2

    static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dexterDirectory = applicationSupportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        return dexterDirectory.appendingPathComponent("persistent-memory.json", isDirectory: false)
    }

    init(storageURL: URL? = PersistentMemoryStore.defaultStorageURL()) {
        self.storageURL = storageURL
        if let storageURL {
            self.state = Self.loadState(from: storageURL) ?? PersistedDexterMemoryStateV2(
                version: 2,
                memories: [],
                activeTaskDescription: nil,
                workflowContext: nil
            )
        } else {
            self.state = PersistedDexterMemoryStateV2(
                version: 2,
                memories: [],
                activeTaskDescription: nil,
                workflowContext: nil
            )
        }
    }

    var activeTaskDescription: String? {
        get { state.activeTaskDescription }
        set {
            state.activeTaskDescription = newValue
            persistIfNeeded()
        }
    }

    var workflowContext: DexterWorkflowContextState? {
        get { state.workflowContext }
        set {
            state.workflowContext = newValue
            persistIfNeeded()
        }
    }

    func allMemories() -> [DexterStructuredMemoryRecord] {
        state.memories.sorted { $0.timestamp > $1.timestamp }
    }

    func activeMemories() -> [DexterStructuredMemoryRecord] {
        allMemories().filter { $0.status == .active }
    }

    func mutateMemories(_ mutation: (inout [DexterStructuredMemoryRecord]) -> Void) {
        mutation(&state.memories)
        persistIfNeeded()
    }

    func appendMemory(_ record: DexterStructuredMemoryRecord) {
        state.memories.append(record)
        persistIfNeeded()
    }

    func removeMemory(id: UUID) {
        state.memories.removeAll { $0.id == id }
        persistIfNeeded()
    }

    func clearMemories(type: DexterMemoryType?) {
        if let type {
            state.memories.removeAll { $0.type == type }
        } else {
            state.memories.removeAll()
        }
        persistIfNeeded()
    }

    func clearWorkflowContext() {
        state.workflowContext = nil
        persistIfNeeded()
    }

    func clearActiveTask() {
        state.activeTaskDescription = nil
        persistIfNeeded()
    }

    private func persistIfNeeded() {
        guard let storageURL else { return }

        let fileManager = FileManager.default
        let directoryURL = storageURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        state.version = 2
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encodedData = try? encoder.encode(state) else { return }
        try? encodedData.write(to: storageURL, options: [.atomic])
    }

    private static func loadState(from storageURL: URL) -> PersistedDexterMemoryStateV2? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let v2 = try? decoder.decode(PersistedDexterMemoryStateV2.self, from: data) {
            return v2
        }

        if let v1 = try? decoder.decode(PersistedDexterMemoryStateV1.self, from: data) {
            return migrateFromV1(v1)
        }

        return nil
    }

    private static func migrateFromV1(_ v1: PersistedDexterMemoryStateV1) -> PersistedDexterMemoryStateV2 {
        let migratedMemories = v1.entries.map { entry -> DexterStructuredMemoryRecord in
            let type: DexterMemoryType = entry.kind == .userPreference ? .preference : .semantic
            let source: DexterMemorySource
            switch entry.provenance {
            case .explicitUserRequest: source = .explicitUserUtterance
            case .intentionalPreference: source = .explicitUserUtterance
            case .workflowRequired: source = .workflowSystem
            }
            return DexterStructuredMemoryRecord(
                id: entry.id,
                type: type,
                content: entry.content,
                source: source,
                timestamp: entry.createdAt,
                confidence: 0.95,
                importance: type == .preference ? 0.9 : 0.8,
                project: nil,
                status: .active,
                expiration: nil,
                supersedes: nil,
                permissions: .defaultForExplicitUser,
                title: entry.title
            )
        }

        return PersistedDexterMemoryStateV2(
            version: 2,
            memories: migratedMemories,
            activeTaskDescription: v1.activeTaskDescription,
            workflowContext: v1.workflowContext
        )
    }
}
