//
//  DexterActionRecoveryLedger.swift
//  leanring-buddy
//

import Foundation

struct DexterActionRecoveryLedgerEntry: Equatable {
    let metadata: DexterActionRecoveryMetadata
    let completedAction: DexterAction
}

final class DexterActionRecoveryLedger {
    private var entries: [DexterActionRecoveryLedgerEntry] = []
    private let maxEntryCount: Int

    init(maxEntryCount: Int = 8) {
        self.maxEntryCount = max(1, maxEntryCount)
    }

    func recordCompletedAction(metadata: DexterActionRecoveryMetadata, action: DexterAction) {
        guard action.state == .completed else { return }
        entries.removeAll { $0.metadata.actionIdentifier == metadata.actionIdentifier }
        entries.insert(
            DexterActionRecoveryLedgerEntry(metadata: metadata, completedAction: action),
            at: 0
        )
        if entries.count > maxEntryCount {
            entries = Array(entries.prefix(maxEntryCount))
        }
        DexterObservabilityLog.observe(
            "action_recovery recorded reversible=\(metadata.reversible) type=\(metadata.actionTypeRawValue)"
        )
    }

    func latestUndoableEntry() -> DexterActionRecoveryLedgerEntry? {
        entries.first { entry in
            entry.metadata.reversible && rollbackAction(for: entry.metadata) != nil
        }
    }

    func latestEntry() -> DexterActionRecoveryLedgerEntry? {
        entries.first
    }

    func rollbackAction(for metadata: DexterActionRecoveryMetadata) -> DexterAction? {
        DexterActionRecoveryEngine.rollbackAction(for: metadata)
    }

    func clear() {
        entries.removeAll()
    }
}
