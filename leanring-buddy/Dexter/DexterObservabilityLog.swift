//
//  DexterObservabilityLog.swift
//  leanring-buddy
//
//  Structured tracing logs. Never logs secrets, tokens, passwords, or raw screen/clipboard content.
//

import Foundation

enum DexterObservabilityLog {
    private static func prefix(for category: String) -> String {
        if let taskIdentifier = DexterTaskTraceRecorder.shared.currentTaskIdentifier {
            return "[DEXTER][\(category)] task_id=\(String(taskIdentifier.uuidString.prefix(8)))"
        }
        return "[DEXTER][\(category)]"
    }

    private static func printLine(category: String, message: String) {
        let sanitized = DexterObservabilityRedaction.redact(message)
        print("\(prefix(for: category)) \(sanitized)")
    }

    static func task(_ message: String) {
        printLine(category: "TASK", message: message)
    }

    static func context(_ message: String) {
        printLine(category: "CONTEXT", message: message)
    }

    static func intent(_ message: String) {
        printLine(category: "INTENT", message: message)
    }

    static func plan(_ message: String) {
        printLine(category: "PLAN", message: message)
    }

    static func permission(_ message: String) {
        printLine(category: "PERMISSION", message: message)
    }

    static func tool(_ message: String) {
        printLine(category: "TOOL", message: message)
    }

    static func openClaw(_ message: String) {
        printLine(category: "OPENCLAW", message: message)
    }

    static func observe(_ message: String) {
        printLine(category: "OBSERVE", message: message)
    }

    static func verify(_ message: String) {
        printLine(category: "VERIFY", message: message)
    }

    static func memory(_ message: String) {
        printLine(category: "MEMORY", message: message)
    }

    static func voice(_ message: String) {
        printLine(category: "VOICE", message: message)
    }

    static func perf(_ message: String) {
        printLine(category: "PERF", message: message)
    }
}
