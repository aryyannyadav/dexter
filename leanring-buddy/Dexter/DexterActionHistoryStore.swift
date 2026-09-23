//
//  DexterActionHistoryStore.swift
//  leanring-buddy
//

import Foundation

protocol DexterActionHistoryStore: AnyObject {
    func recordAction(actionIdentifier: String, summary: String)
    func recentActions(limit: Int) -> [DexterRecordedAction]
}

final class InMemoryDexterActionHistoryStore: DexterActionHistoryStore {
    private let maxStoredActions: Int
    private var recordedActions: [DexterRecordedAction] = []

    init(maxStoredActions: Int = 20) {
        self.maxStoredActions = max(1, maxStoredActions)
    }

    func recordAction(actionIdentifier: String, summary: String) {
        recordedActions.append(DexterRecordedAction(
            actionIdentifier: actionIdentifier,
            summary: summary,
            recordedAt: Date()
        ))
        if recordedActions.count > maxStoredActions {
            recordedActions.removeFirst(recordedActions.count - maxStoredActions)
        }
    }

    func recentActions(limit: Int) -> [DexterRecordedAction] {
        guard limit > 0 else { return [] }
        if recordedActions.count <= limit {
            return recordedActions
        }
        return Array(recordedActions.suffix(limit))
    }
}
