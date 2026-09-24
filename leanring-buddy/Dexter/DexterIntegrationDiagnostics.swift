//
//  DexterIntegrationDiagnostics.swift
//  leanring-buddy
//

import Foundation

/// Runs microphone, screen capture, and minimal Ollama vision checks (no full orchestrator).
enum DexterIntegrationDiagnostics {
    @MainActor
    static func runAllOnLaunchIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "dexter.integrationDiagnosticsOnLaunch") else {
            return
        }

        Task {
            await runAll()
        }
    }

    @MainActor
    static func runAll() async {
        print("[DEXTER] integration diagnostics starting")

        let microphoneResult = await DexterMicrophoneInputDiagnostic.runTwoSecondCaptureTest()
        print("[DEXTER] mic diagnostic buffers=\(microphoneResult.bufferCount) peakRMS=\(microphoneResult.peakRMS)")

        let screenResult = await DexterOneScreenImageCapture.captureOneScreenImage()
        if let jpegData = screenResult.jpegData {
            let visionResult = await DexterOllamaMinimalVisionDiagnostic.run(jpegData: jpegData)
            print("[DEXTER] vision diagnostic status=\(visionResult.httpStatus ?? -1) text=\(visionResult.assistantText?.prefix(80) ?? "nil")")
        } else {
            print("[DEXTER] vision diagnostic skipped — no JPEG (\(screenResult.errorDescription ?? "unknown"))")
        }

        print("[DEXTER] integration diagnostics finished")
    }
}
