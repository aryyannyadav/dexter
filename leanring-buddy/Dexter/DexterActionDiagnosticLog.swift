//
//  DexterActionDiagnosticLog.swift
//  leanring-buddy
//

import Foundation

enum DexterActionDiagnosticLog {
    static func intent(_ message: String) {
        print("[DEXTER][INTENT] \(message)")
    }

    static func plan(_ message: String) {
        print("[DEXTER][PLAN] \(message)")
    }

    static func permission(_ message: String) {
        print("[DEXTER][PERMISSION] \(message)")
    }

    static func action(_ message: String) {
        print("[DEXTER][ACTION] \(message)")
    }

    static func verify(_ message: String) {
        print("[DEXTER][VERIFY] \(message)")
    }
}
