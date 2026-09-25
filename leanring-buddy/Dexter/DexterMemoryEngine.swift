//
//  DexterMemoryEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterMemoryEngine {
    static func saveExplicit(
        record: DexterStructuredMemoryRecord,
        in store: inout [DexterStructuredMemoryRecord]
    ) -> Result<DexterStructuredMemoryRecord, DexterMemoryError> {
        switch DexterMemoryContentPolicy.evaluateForStorage(record.content, source: record.source) {
        case .rejected(let reason):
            return .failure(.storageRejected(reason))
        case .allowed:
            break
        }

        if let conflicting = findActiveConflict(for: record, in: store) {
            markSuperseded(conflicting.id, in: &store)
            let superseding = DexterStructuredMemoryRecord(
                type: record.type,
                content: record.content,
                source: record.source,
                confidence: record.confidence,
                importance: record.importance,
                project: record.project,
                status: .active,
                expiration: record.expiration,
                supersedes: conflicting.id,
                permissions: record.permissions,
                title: record.title,
                scope: record.scope,
                dexterProfileId: record.dexterProfileId,
                fileWorkspaceId: record.fileWorkspaceId
            )
            store.append(superseding)
            return .success(superseding)
        }

        store.append(record)
        return .success(record)
    }

    static func forget(
        matching query: String,
        in store: inout [DexterStructuredMemoryRecord]
    ) -> Bool {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return false }

        var didForget = false
        for index in store.indices {
            guard store[index].status == .active else { continue }
            let content = store[index].content.lowercased()
            let title = (store[index].title ?? "").lowercased()
            if content.contains(normalizedQuery) || title.contains(normalizedQuery) {
                store[index] = store[index].withStatus(.forgotten)
                didForget = true
            }
        }
        return didForget
    }

    static func update(
        matching query: String,
        newContent: String,
        in store: inout [DexterStructuredMemoryRecord]
    ) -> Bool {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard case .allowed = DexterMemoryContentPolicy.evaluateForStorage(newContent, source: .explicitUserUtterance) else {
            return false
        }

        let existing: DexterStructuredMemoryRecord?
        if normalizedQuery.isEmpty {
            existing = store
                .filter { $0.status == .active }
                .sorted { $0.timestamp > $1.timestamp }
                .first
        } else {
            existing = store.first(where: { memory in
                memory.status == .active
                    && (memory.content.lowercased().contains(normalizedQuery)
                        || (memory.title ?? "").lowercased().contains(normalizedQuery))
            })
        }

        guard let existing else {
            return false
        }

        markSuperseded(existing.id, in: &store)
        let updated = DexterStructuredMemoryRecord(
            type: existing.type,
            content: newContent,
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
        store.append(updated)
        return true
    }

    static func summaryForRecall(from memories: [DexterStructuredMemoryRecord], limit: Int = 12) -> String {
        let retrieved = DexterMemoryRetrievalEngine.retrieve(query: "", from: memories, limit: limit)
        if retrieved.isEmpty {
            return "I don't have any active memories saved yet. Say “remember that …” when you want me to store something."
        }

        let lines = retrieved.map { memory in
            let label = memory.title ?? memory.type.rawValue
            return "- [\(label)] \(memory.content)"
        }
        return "Here's what I remember:\n" + lines.joined(separator: "\n")
    }

    private static func findActiveConflict(
        for record: DexterStructuredMemoryRecord,
        in store: [DexterStructuredMemoryRecord]
    ) -> DexterStructuredMemoryRecord? {
        let normalizedNew = record.content.lowercased()
        return store.first { existing in
            existing.status == .active
                && existing.type == record.type
                && existing.project == record.project
                && existing.scope == record.scope
                && existing.dexterProfileId == record.dexterProfileId
                && existing.fileWorkspaceId == record.fileWorkspaceId
                && (
                    existing.content.lowercased() == normalizedNew
                        || normalizedNew.contains(existing.content.lowercased())
                        || existing.content.lowercased().contains(normalizedNew)
                )
        }
    }

    private static func markSuperseded(_ identifier: UUID, in store: inout [DexterStructuredMemoryRecord]) {
        for index in store.indices where store[index].id == identifier {
            store[index] = store[index].withStatus(.superseded)
        }
    }
}

extension DexterStructuredMemoryRecord {
    func withStatus(_ newStatus: DexterMemoryStatus) -> DexterStructuredMemoryRecord {
        DexterStructuredMemoryRecord(
            id: id,
            type: type,
            content: content,
            source: source,
            timestamp: timestamp,
            updatedAt: Date(),
            confidence: confidence,
            importance: importance,
            project: project,
            status: newStatus,
            expiration: expiration,
            supersedes: supersedes,
            permissions: permissions,
            title: title,
            scope: scope,
            dexterProfileId: dexterProfileId,
            fileWorkspaceId: fileWorkspaceId
        )
    }

    func withUpdatedContent(_ newContent: String) -> DexterStructuredMemoryRecord {
        DexterStructuredMemoryRecord(
            id: id,
            type: type,
            content: newContent,
            source: .explicitUserUtterance,
            timestamp: timestamp,
            updatedAt: Date(),
            confidence: max(confidence, 0.95),
            importance: importance,
            project: project,
            status: .active,
            expiration: expiration,
            supersedes: supersedes,
            permissions: .defaultForExplicitUser,
            title: title,
            scope: scope,
            dexterProfileId: dexterProfileId,
            fileWorkspaceId: fileWorkspaceId
        )
    }
}
