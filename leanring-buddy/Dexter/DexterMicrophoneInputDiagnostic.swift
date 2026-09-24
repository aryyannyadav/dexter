//
//  DexterMicrophoneInputDiagnostic.swift
//  leanring-buddy
//

import AVFoundation
import Foundation

/// Captures ~2 seconds of mic input without STT or Ollama. Used to verify the audio engine receives samples.
enum DexterMicrophoneInputDiagnostic {
    struct Result: Equatable {
        let permissionGranted: Bool
        let audioEngineStarted: Bool
        let bufferCount: Int
        let peakRMS: Float
    }

    @MainActor
    static func runTwoSecondCaptureTest() async -> Result {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DexterMicDiagnosticLog.log("permission status: \(describe(authorizationStatus))")

        if authorizationStatus == .notDetermined {
            DexterMicDiagnosticLog.log("requesting permission")
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
            DexterMicDiagnosticLog.log("permission result: \(granted ? "granted" : "denied")")
            if !granted {
                return Result(permissionGranted: false, audioEngineStarted: false, bufferCount: 0, peakRMS: 0)
            }
        } else if authorizationStatus != .authorized {
            return Result(permissionGranted: false, audioEngineStarted: false, bufferCount: 0, peakRMS: 0)
        }

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        DexterMicDiagnosticLog.log("input node format: sampleRate=\(inputFormat.sampleRate) channels=\(inputFormat.channelCount)")

        var bufferCount = 0
        var peakRMS: Float = 0
        let captureLock = NSLock()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            var summedSquares: Float = 0
            for sampleIndex in 0..<frameCount {
                let sample = channelData[0][sampleIndex]
                summedSquares += sample * sample
            }
            let rootMeanSquare = sqrt(summedSquares / Float(frameCount))

            captureLock.lock()
            bufferCount += 1
            peakRMS = max(peakRMS, rootMeanSquare)
            captureLock.unlock()

            if bufferCount == 1 {
                DexterMicDiagnosticLog.log("received audio buffer size=\(frameCount) frames")
            }
        }
        DexterMicDiagnosticLog.log("tap installed")

        do {
            audioEngine.prepare()
            try audioEngine.start()
            DexterMicDiagnosticLog.log("audio engine started")
        } catch {
            DexterMicDiagnosticLog.log("audio engine failed: \(error.localizedDescription)")
            inputNode.removeTap(onBus: 0)
            return Result(permissionGranted: true, audioEngineStarted: false, bufferCount: 0, peakRMS: 0)
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)

        captureLock.lock()
        let finalBufferCount = bufferCount
        let finalPeakRMS = peakRMS
        captureLock.unlock()

        DexterMicDiagnosticLog.log("diagnostic complete buffers=\(finalBufferCount) peakRMS=\(String(format: "%.5f", finalPeakRMS))")

        return Result(
            permissionGranted: true,
            audioEngineStarted: true,
            bufferCount: finalBufferCount,
            peakRMS: finalPeakRMS
        )
    }

    private static func describe(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
}
