//
//  DexterPermissionDiagnostics.swift
//  leanring-buddy
//

import AVFoundation
import CoreGraphics
import Foundation

enum DexterPermissionDiagnostics {
    static func logMicrophoneAuthorizationStatus() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DexterDiagnosticLog.permissionMic("authorization status: \(describeAVAuthorization(authorizationStatus))")
    }

    static func logMicrophoneRequestAccessInvoked() {
        DexterDiagnosticLog.permissionMic("requestAccess(for: .audio) invoked")
    }

    static func logMicrophoneRequestAccessResult(granted: Bool) {
        DexterDiagnosticLog.permissionMic("requestAccess result: \(granted ? "granted" : "denied")")
    }

    static func logSelectedAudioInputDevice() {
        guard let device = AVCaptureDevice.default(for: .audio) else {
            DexterDiagnosticLog.permissionMic("no default audio input device")
            return
        }
        DexterDiagnosticLog.permissionMic("default audio input: \(device.localizedName) (connected: \(device.isConnected))")
    }

    static func logAudioEngineStarted() {
        DexterDiagnosticLog.permissionMic("AVAudioEngine started")
    }

    static func logAudioEngineStartFailed(_ error: Error) {
        DexterDiagnosticLog.permissionMic("AVAudioEngine failed to start: \(error.localizedDescription)")
    }

    static func logNonZeroAudioSamplesReceived(rmsLevel: Float) {
        DexterDiagnosticLog.permissionMic("input buffers contain non-zero samples (rms: \(String(format: "%.4f", rmsLevel)))")
    }

    static func logSTTAudioBufferForwarded() {
        DexterDiagnosticLog.stt("audio buffer forwarded to transcription provider")
    }

    static func logScreenRecordingPreflight(_ granted: Bool) {
        DexterDiagnosticLog.permissionScreen("CGPreflightScreenCaptureAccess: \(granted)")
    }

    static func logScreenRecordingRequestAccessInvoked() {
        DexterDiagnosticLog.permissionScreen("CGRequestScreenCaptureAccess invoked")
    }

    static func logScreenRecordingRequestAccessResult(_ granted: Bool) {
        DexterDiagnosticLog.permissionScreen("CGRequestScreenCaptureAccess result: \(granted)")
    }

    static func logShareableContentDisplays(count: Int) {
        DexterDiagnosticLog.permissionScreen("ScreenCaptureKit displays: \(count)")
    }

    static func logScreenshotProbeResult(width: Int, height: Int, succeeded: Bool) {
        DexterDiagnosticLog.permissionScreen("screenshot probe \(width)x\(height), succeeded: \(succeeded)")
    }

    static func logScreenshotConversionResult(succeeded: Bool, byteCount: Int) {
        DexterDiagnosticLog.permissionScreen("JPEG conversion succeeded: \(succeeded), bytes: \(byteCount)")
    }

    private static func describeAVAuthorization(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }
}
