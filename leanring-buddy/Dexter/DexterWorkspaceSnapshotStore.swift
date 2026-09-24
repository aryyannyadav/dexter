//
//  DexterWorkspaceSnapshotStore.swift
//  leanring-buddy
//

import Foundation

final class DexterWorkspaceSnapshotStore {
    private struct PersistedState: Codable, Equatable {
        var version: Int
        var snapshots: [DexterWorkspaceSnapshot]
    }

    private let storageURL: URL?
    private var state: PersistedState
    private let maxSnapshotCount: Int

    static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dexterDirectory = applicationSupportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        return dexterDirectory.appendingPathComponent("workspace-snapshots.json", isDirectory: false)
    }

    init(
        storageURL: URL? = DexterWorkspaceSnapshotStore.defaultStorageURL(),
        maxSnapshotCount: Int = 5
    ) {
        self.storageURL = storageURL
        self.maxSnapshotCount = max(1, maxSnapshotCount)
        if let storageURL, let loaded = Self.loadState(from: storageURL) {
            state = loaded
        } else {
            state = PersistedState(version: 1, snapshots: [])
        }
    }

    func allSnapshots() -> [DexterWorkspaceSnapshot] {
        state.snapshots.sorted { $0.capturedAt > $1.capturedAt }
    }

    func latestSnapshot() -> DexterWorkspaceSnapshot? {
        allSnapshots().first
    }

    func save(_ snapshot: DexterWorkspaceSnapshot) {
        state.snapshots.removeAll { $0.id == snapshot.id }
        state.snapshots.insert(snapshot, at: 0)
        if state.snapshots.count > maxSnapshotCount {
            state.snapshots = Array(state.snapshots.prefix(maxSnapshotCount))
        }
        persistIfNeeded()
    }

    func removeSnapshot(identifier: UUID) {
        state.snapshots.removeAll { $0.id == identifier }
        persistIfNeeded()
    }

    private func persistIfNeeded() {
        guard let storageURL else { return }
        let fileManager = FileManager.default
        let directoryURL = storageURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            DexterObservabilityLog.memory("workspace snapshot persist failed")
        }
    }

    private static func loadState(from storageURL: URL) -> PersistedState? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedState.self, from: data)
        } catch {
            return nil
        }
    }
}
