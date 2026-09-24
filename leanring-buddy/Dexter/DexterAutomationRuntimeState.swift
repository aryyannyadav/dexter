//
//  DexterAutomationRuntimeState.swift
//  leanring-buddy
//

import Foundation

/// High-level automation lifecycle (distinct from per-action `DexterExecutionPhase`).
enum DexterAutomationRuntimeState: String, Equatable, CaseIterable {
    case running = "RUNNING"
    case stopping = "STOPPING"
    case stopped = "STOPPED"
    case failed = "FAILED"
    case recovering = "RECOVERING"
}

enum DexterAutomationRuntimeStateLog {
    static func log(state: DexterAutomationRuntimeState, detail: String? = nil) {
        if let detail, !detail.isEmpty {
            print("[DEXTER][AUTOMATION] state=\(state.rawValue) \(detail)")
        } else {
            print("[DEXTER][AUTOMATION] state=\(state.rawValue)")
        }
    }
}
