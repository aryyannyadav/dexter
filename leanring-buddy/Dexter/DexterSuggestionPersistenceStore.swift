//
//  DexterSuggestionPersistenceStore.swift
//  leanring-buddy
//

import Foundation

struct DexterSuggestionPersistenceRecord: Codable, Equatable {
    var lastShownAt: Date?
    var dismissedAt: Date?
    var acceptedAt: Date?
    var completedAt: Date?
    var showCount: Int
}

@MainActor
final class DexterSuggestionPersistenceStore {
    private let fileURL: URL
    private var records: [String: DexterSuggestionPersistenceRecord] = [:]

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dexterDirectory = supportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dexterDirectory, withIntermediateDirectories: true)
        fileURL = dexterDirectory.appendingPathComponent("suggestion-state.json")
        loadFromDisk()
    }

    func record(for suggestionIdentifier: String) -> DexterSuggestionPersistenceRecord {
        records[suggestionIdentifier] ?? DexterSuggestionPersistenceRecord(showCount: 0)
    }

    func shouldOfferSuggestion(identifier: String, now: Date) -> Bool {
        let record = record(for: identifier)
        if record.completedAt != nil {
            return false
        }
        if let dismissedAt = record.dismissedAt {
            let daysSinceDismiss = now.timeIntervalSince(dismissedAt) / 86_400
            if daysSinceDismiss < 7 {
                return false
            }
        }
        return true
    }

    func markShown(identifier: String, at date: Date = Date()) {
        var record = record(for: identifier)
        record.lastShownAt = date
        record.showCount += 1
        records[identifier] = record
        saveToDisk()
    }

    func markDismissed(identifier: String, at date: Date = Date()) {
        var record = record(for: identifier)
        record.dismissedAt = date
        records[identifier] = record
        saveToDisk()
    }

    func markAccepted(identifier: String, at date: Date = Date()) {
        var record = record(for: identifier)
        record.acceptedAt = date
        records[identifier] = record
        saveToDisk()
    }

    func markCompleted(identifier: String, at date: Date = Date()) {
        var record = record(for: identifier)
        record.completedAt = date
        records[identifier] = record
        saveToDisk()
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: DexterSuggestionPersistenceRecord].self, from: data) else {
            return
        }
        records = decoded
    }

    private func saveToDisk() {
        guard let encoded = try? JSONEncoder().encode(records) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
