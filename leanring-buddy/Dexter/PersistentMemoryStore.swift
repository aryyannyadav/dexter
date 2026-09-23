//
//  PersistentMemoryStore.swift
//  leanring-buddy
//

import Foundation

/// Disk-backed store for explicit preferences, remembered facts, task, and workflow state.
final class PersistentMemoryStore {
    private struct PersistedDexterMemoryState: Codable, Equatable {
        var entries: [DexterMemoryEntry]
        var activeTaskDescription: String?
        var workflowContext: DexterWorkflowContextState?
    }

    private let storageURL: URL?
    private var state: PersistedDexterMemoryState

    static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dexterDirectory = applicationSupportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        return dexterDirectory.appendingPathComponent("persistent-memory.json", isDirectory: false)
    }

    init(storageURL: URL? = PersistentMemoryStore.defaultStorageURL()) {
        self.storageURL = storageURL
        if let storageURL {
            self.state = Self.loadState(from: storageURL) ?? PersistedDexterMemoryState(
                entries: [],
                activeTaskDescription: nil,
                workflowContext: nil
            )
        } else {
            self.state = PersistedDexterMemoryState(
                entries: [],
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

    func allEntries() -> [DexterMemoryEntry] {
        state.entries.sorted { $0.createdAt > $1.createdAt }
    }

    func entries(kind: DexterMemoryEntryKind) -> [DexterMemoryEntry] {
        allEntries().filter { $0.kind == kind }
    }

    func appendEntry(_ entry: DexterMemoryEntry) {
        state.entries.append(entry)
        persistIfNeeded()
    }

    func removeEntry(id: UUID) {
        state.entries.removeAll { $0.id == id }
        persistIfNeeded()
    }

    func clearEntries(kind: DexterMemoryEntryKind?) {
        if let kind {
            state.entries.removeAll { $0.kind == kind }
        } else {
            state.entries.removeAll()
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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encodedData = try? encoder.encode(state) else { return }
        try? encodedData.write(to: storageURL, options: [.atomic])
    }

    private static func loadState(from storageURL: URL) -> PersistedDexterMemoryState? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedDexterMemoryState.self, from: data)
    }
}
