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
        let turnIdentifier = UUID()
        currentTurnIdentifier = turnIdentifier
        log("received user request")
        return turnIdentifier
    }

    static func endTurn() {
        currentTurnIdentifier = nil
    }

    static func finish(outcome: DexterTurnOutcome) {
        log("orchestrator completed outcome=\(outcome.rawValue)")
        endTurn()
    }

    static func log(_ message: String) {
        guard let turnIdentifier = currentTurnIdentifier else {
            print("[TURN] \(message)")
            return
        }
        let shortIdentifier = turnIdentifier.uuidString.prefix(8)
        print("[TURN \(shortIdentifier)] \(message)")
    }
}
