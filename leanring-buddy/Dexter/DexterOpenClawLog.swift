//
//  DexterOpenClawLog.swift
//  leanring-buddy
//

import Foundation

enum DexterOpenClawLog {
    static func log(_ message: String) {
        DexterTaskTraceRecorder.shared.markPhase(.toolCalls)
        DexterObservabilityLog.openClaw(message)
    }

    static func logTimedInvocation(startedAt: Date, detail: String) {
        let milliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
        DexterTaskTraceRecorder.shared.recordLatency(bucket: .openClaw, milliseconds: milliseconds)
        log("\(detail) latency_ms=\(milliseconds)")
    }
}
