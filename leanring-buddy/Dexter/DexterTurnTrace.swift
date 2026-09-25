//
//  DexterTurnTrace.swift
//  leanring-buddy
//

import Foundation

enum DexterTurnOutcome: String {
    case success = "SUCCESS"
    case error = "ERROR"
    case cancelled = "CANCELLED"
    case timeout = "TIMEOUT"
}

enum DexterTurnTrace {
    private(set) static var currentTurnIdentifier: UUID?

    static func beginTurn() -> UUID {
        let turnIdentifier = DexterTaskTraceRecorder.shared.beginTask()
        currentTurnIdentifier = turnIdentifier
        log("invocation received")
        return turnIdentifier
    }

    static func endTurn() {
        currentTurnIdentifier = nil
    }

    static func finish(
        outcome: DexterTurnOutcome,
        operationalOutcome: DexterOperationalOutcomeCategory? = nil
    ) {
        let resolvedOperationalOutcome = operationalOutcome ?? DexterTaskTraceRecorder.mapTurnOutcome(outcome)
        DexterTaskTraceRecorder.shared.endTask(outcome: resolvedOperationalOutcome)
        log("outcome=\(resolvedOperationalOutcome.rawValue)")
        endTurn()
    }

    static func log(_ message: String) {
        DexterObservabilityLog.task(DexterObservabilityRedaction.redact(message))
    }
}
