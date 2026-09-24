//
//  DexterTaskStateStore.swift
//  leanring-buddy
//

import Foundation

protocol DexterTaskStateStore: AnyObject {
    var currentTaskDescription: String? { get set }
    var activeWorkflowTask: DexterTask? { get set }
    var activeLearnedWorkflowRun: DexterWorkflowRunSession? { get set }
}

extension DexterTaskStateStore {
    var activeLearnedWorkflowRun: DexterWorkflowRunSession? {
        get { nil }
        set { _ = newValue }
    }
}

final class InMemoryDexterTaskStateStore: DexterTaskStateStore {
    var currentTaskDescription: String?
    var activeWorkflowTask: DexterTask?
    var activeLearnedWorkflowRun: DexterWorkflowRunSession?
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

    var activeLearnedWorkflowRun: DexterWorkflowRunSession? {
        get { storedActiveLearnedWorkflowRun }
        set {
            storedActiveLearnedWorkflowRun = newValue
            if let newValue, !newValue.isTerminal {
                memoryStore.setWorkflowContext(
                    DexterWorkflowContextState(
                        summary: "\(newValue.workflowName) — \(newValue.progressLabel), phase \(newValue.runtimePhase.rawValue)"
                    ),
                    provenance: .workflowRequired
                )
            } else if storedActiveWorkflowTask == nil {
                memoryStore.clearWorkflowContext()
            }
        }
    }

    private var storedActiveLearnedWorkflowRun: DexterWorkflowRunSession?
}
