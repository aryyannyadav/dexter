//
//  DexterScreenCapturePermissionProbe.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum DexterScreenCapturePermissionProbe {
    /// Returns true only when Screen Recording is granted and a tiny test frame can be captured.
    static func captureTestFrameSucceeded() async -> Bool {
        let preflightGranted = CGPreflightScreenCaptureAccess()
        DexterPermissionDiagnostics.logScreenRecordingPreflight(preflightGranted)
        guard preflightGranted else { return false }

        DexterScreenCaptureDiagnostics.logCaptureStart(reason: "capability-probe")

        do {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            DexterPermissionDiagnostics.logShareableContentDisplays(count: shareableContent.displays.count)
            guard let display = shareableContent.displays.first else { return false }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 320
            configuration.height = 240

            let capturedImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            let succeeded = capturedImage.width > 0 && capturedImage.height > 0
            DexterPermissionDiagnostics.logScreenshotProbeResult(
                width: capturedImage.width,
                height: capturedImage.height,
                succeeded: succeeded
            )

            guard succeeded else {
                DexterPermissionDiagnostics.logScreenshotConversionResult(succeeded: false, byteCount: 0)
                return false
            }

            DexterScreenCaptureDiagnostics.logJPEGConversion(reason: "capability-probe")
            guard let jpegData = NSBitmapImageRep(cgImage: capturedImage)
                    .representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
                DexterPermissionDiagnostics.logScreenshotConversionResult(succeeded: false, byteCount: 0)
                return false
            }

            DexterPermissionDiagnostics.logScreenshotConversionResult(succeeded: true, byteCount: jpegData.count)
            return true
        } catch {
            DexterDiagnosticLog.permissionScreen("probe failed: \(error.localizedDescription)")
            return false
        }
    }
}
