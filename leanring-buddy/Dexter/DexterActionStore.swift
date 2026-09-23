//
//  DexterActionStore.swift
//  leanring-buddy
//

import Foundation

protocol DexterActionStore: AnyObject {
    func register(_ action: DexterAction)
    func update(_ action: DexterAction)
    func action(withId actionId: UUID) -> DexterAction?
    func recentActions(limit: Int) -> [DexterAction]
}

@MainActor
final class InMemoryDexterActionStore: DexterActionStore {
    private let maxStoredActions: Int
    private var actionsById: [UUID: DexterAction] = [:]
    private var orderedActionIds: [UUID] = []

    init(maxStoredActions: Int = 50) {
        self.maxStoredActions = max(1, maxStoredActions)
    }

    func register(_ action: DexterAction) {
        actionsById[action.id] = action
        orderedActionIds.append(action.id)
        trimIfNeeded()
    }

    func update(_ action: DexterAction) {
        guard actionsById[action.id] != nil else { return }
        actionsById[action.id] = action
    }

    func action(withId actionId: UUID) -> DexterAction? {
        actionsById[actionId]
    }

    func recentActions(limit: Int) -> [DexterAction] {
        guard limit > 0 else { return [] }
        let ids = orderedActionIds.suffix(limit)
        return ids.compactMap { actionsById[$0] }
    }

    private func trimIfNeeded() {
        while orderedActionIds.count > maxStoredActions {
            let removedId = orderedActionIds.removeFirst()
            actionsById.removeValue(forKey: removedId)
        }
    }
}
