//
//  DexterActivityStore.swift
//  leanring-buddy
//

import Foundation

/// Bounded on-disk activity timeline (user-facing events only).
final class DexterActivityStore {
    private struct PersistedState: Codable {
        var version: Int
        var events: [DexterActivityRecord]
    }

    private let storageURL: URL?
    private let maxStoredEvents: Int
    private var state: PersistedState

    static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dexterDirectory = applicationSupportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        return dexterDirectory.appendingPathComponent("activity-timeline.json", isDirectory: false)
    }

    init(storageURL: URL? = DexterActivityStore.defaultStorageURL(), maxStoredEvents: Int = 250) {
        self.storageURL = storageURL
        self.maxStoredEvents = max(50, maxStoredEvents)
        if let storageURL {
            self.state = Self.loadState(from: storageURL) ?? PersistedState(version: 1, events: [])
        } else {
            self.state = PersistedState(version: 1, events: [])
        }
    }

    static func inMemoryForTesting() -> DexterActivityStore {
        DexterActivityStore(storageURL: nil, maxStoredEvents: 100)
    }

    func allEvents() -> [DexterActivityRecord] {
        state.events
    }

    func prepend(_ record: DexterActivityRecord) {
        state.events.insert(record, at: 0)
        if state.events.count > maxStoredEvents {
            state.events = Array(state.events.prefix(maxStoredEvents))
        }
        persistIfNeeded()
    }

    func events(
        forProfileId profileId: UUID?,
        includeGlobal: Bool,
        filter: DexterActivityFilter,
        limit: Int
    ) -> [DexterActivityRecord] {
        let filtered = state.events.filter { record in
            guard filter.matches(record) else { return false }
            if profileId == nil { return true }
            if record.dexterProfileId == profileId { return true }
            if includeGlobal, record.dexterProfileId == nil { return true }
            return false
        }
        guard limit > 0 else { return filtered }
        return Array(filtered.prefix(limit))
    }

    func event(withId id: UUID) -> DexterActivityRecord? {
        state.events.first { $0.id == id }
    }

    private func persistIfNeeded() {
        guard let storageURL else { return }
        let fileManager = FileManager.default
        let directoryURL = storageURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        state.version = 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encodedData = try? encoder.encode(state) else { return }
        try? encodedData.write(to: storageURL, options: [.atomic])
    }

    private static func loadState(from storageURL: URL) -> PersistedState? {
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedState.self, from: data)
    }
}
