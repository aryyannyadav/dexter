//
//  DexterAccountabilityTaskStore.swift
//  leanring-buddy
//

import Foundation

final class DexterAccountabilityTaskStore {
    private struct PersistedState: Codable, Equatable {
        var version: Int
        var tasks: [DexterAccountabilityTask]
        var activeTaskIdentifier: UUID?
    }

    private let storageURL: URL?
    private var state: PersistedState

    static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dexterDirectory = applicationSupportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        return dexterDirectory.appendingPathComponent("accountability-tasks.json", isDirectory: false)
    }

    init(storageURL: URL? = DexterAccountabilityTaskStore.defaultStorageURL()) {
        self.storageURL = storageURL
        if let storageURL, let loaded = Self.loadState(from: storageURL) {
            state = loaded
        } else {
            state = PersistedState(version: 1, tasks: [], activeTaskIdentifier: nil)
        }
    }

    func allTasks() -> [DexterAccountabilityTask] {
        state.tasks.sorted { $0.updatedAt > $1.updatedAt }
    }

    func task(forIdentifier identifier: UUID) -> DexterAccountabilityTask? {
        state.tasks.first { $0.id == identifier }
    }

    func activeTask() -> DexterAccountabilityTask? {
        if let activeTaskIdentifier = state.activeTaskIdentifier {
            return task(forIdentifier: activeTaskIdentifier)
        }
        return state.tasks.first { $0.status == .inProgress }
    }

    func openTasks() -> [DexterAccountabilityTask] {
        allTasks().filter(\.isOpen)
    }

    func unfinishedTasks() -> [DexterAccountabilityTask] {
        allTasks().filter { task in
            task.isOpen && (task.status != .notStarted || !task.steps.isEmpty)
        }
    }

    func tasksWithPendingReminders(referenceDate: Date = Date()) -> [DexterAccountabilityTask] {
        allTasks().filter { task in
            guard let remindAt = task.commitment?.remindAt else { return false }
            return remindAt <= referenceDate.addingTimeInterval(60 * 60 * 24 * 365)
        }
    }

    func upsertTask(_ task: DexterAccountabilityTask) {
        if let index = state.tasks.firstIndex(where: { $0.id == task.id }) {
            state.tasks[index] = task
        } else {
            state.tasks.append(task)
        }
        persistIfNeeded()
    }

    func setActiveTaskIdentifier(_ identifier: UUID?) {
        state.activeTaskIdentifier = identifier
        persistIfNeeded()
    }

    func removeTask(identifier: UUID) {
        state.tasks.removeAll { $0.id == identifier }
        if state.activeTaskIdentifier == identifier {
            state.activeTaskIdentifier = nil
        }
        persistIfNeeded()
    }

    func makeSnapshot(referenceDate: Date = Date()) -> DexterAccountabilityTaskSnapshot {
        DexterAccountabilityTaskSnapshot(
            activeTask: activeTask(),
            openTasks: openTasks(),
            unfinishedTasks: unfinishedTasks(),
            pendingReminders: tasksWithPendingReminders(referenceDate: referenceDate)
                .filter { ($0.commitment?.remindAt ?? .distantFuture) >= referenceDate.addingTimeInterval(-300) }
        )
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

    private static func loadState(from storageURL: URL) -> PersistedState? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PersistedState.self, from: data)
    }
}
