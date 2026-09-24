//
//  DexterActionDiagnosticLog.swift
//  leanring-buddy
//

import Foundation

enum DexterActionDiagnosticLog {
    static func intent(_ message: String) {
        DexterTaskTraceRecorder.shared.markPhase(.intent)
        DexterObservabilityLog.intent(message)
    }

    static func plan(_ message: String) {
        DexterTaskTraceRecorder.shared.markPhase(.plan)
        DexterObservabilityLog.plan(message)
    }

    static func permission(_ message: String) {
        DexterTaskTraceRecorder.shared.markPhase(.permission)
        DexterObservabilityLog.permission(message)
    }

    static func action(_ message: String) {
        DexterTaskTraceRecorder.shared.markPhase(.executionResults)
        DexterObservabilityLog.tool(message)
    }

    static func verify(_ message: String) {
        DexterTaskTraceRecorder.shared.markPhase(.verification)
        DexterObservabilityLog.verify(message)
    }
}
