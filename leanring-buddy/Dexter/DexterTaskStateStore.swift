//
//  DexterTaskStateStore.swift
//  leanring-buddy
//

import Foundation

protocol DexterTaskStateStore: AnyObject {
    var currentTaskDescription: String? { get set }
    var activeWorkflowTask: DexterTask? { get set }
}

final class InMemoryDexterTaskStateStore: DexterTaskStateStore {
    var currentTaskDescription: String?
    var activeWorkflowTask: DexterTask?
}

/// Keeps the lightweight memory-store task description in sync with the active workflow title.
final class DexterWorkflowTaskStateStore: DexterTaskStateStore {
    private let memoryStore: MemoryStore

    init(memoryStore: MemoryStore) {
        self.memoryStore = memoryStore
    }

    var currentTaskDescription: String? {
        get {
            if let activeWorkflowTask {
                return activeWorkflowTask.title
            }
            return memoryStore.activeTaskDescription
        }
        set {
            memoryStore.setActiveTask(description: newValue, provenance: .workflowRequired)
        }
    }

    var activeWorkflowTask: DexterTask? {
        get { storedActiveWorkflowTask }
        set {
            storedActiveWorkflowTask = newValue
            if let newValue {
                memoryStore.setActiveTask(description: newValue.title, provenance: .workflowRequired)
                memoryStore.setWorkflowContext(
                    DexterWorkflowContextState(summary: "\(newValue.title) — step \(newValue.progressLabel), state \(newValue.state.rawValue)"),
                    provenance: .workflowRequired
                )
            } else {
                memoryStore.clearWorkflowContext()
            }
        }
    }

    private var storedActiveWorkflowTask: DexterTask?
}
