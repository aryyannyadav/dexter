//
//  DexterDiagnosticLog.swift
//  leanring-buddy
//

import Foundation

/// Structured console diagnostics for voice, model, vision, and TTS pipelines. Never logs secrets or screen contents.
enum DexterDiagnosticLog {
    static func voice(_ message: String) {
        DexterObservabilityLog.voice(message)
    }

    static func stt(_ message: String) {
        print("[DEXTER][STT] \(message)")
    }

    static func model(_ message: String) {
        print("[DEXTER][MODEL] \(message)")
    }

    static func ollama(_ message: String) {
        print("[DEXTER][OLLAMA] \(message)")
    }

    static func vision(_ message: String) {
        print("[DEXTER][VISION] \(message)")
    }

    static func tts(_ message: String) {
        print("[DEXTER][TTS] \(message)")
    }

    static func context(_ message: String) {
        print("[DEXTER][CONTEXT] \(message)")
    }

    static func permissionMic(_ message: String) {
        print("[DEXTER][PERMISSION][MIC] \(message)")
    }

    static func permissionScreen(_ message: String) {
        print("[DEXTER][PERMISSION][SCREEN] \(message)")
    }

    static func ollamaVision(_ message: String) {
        print("[DEXTER][OLLAMA][VISION] \(message)")
    }
}
