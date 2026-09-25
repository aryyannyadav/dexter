//
//  DexterOneScreenImageCapture.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

struct DexterOneScreenImageCaptureResult: Equatable {
    let permissionGranted: Bool
    let displayID: UInt32?
    let originalPixelWidth: Int
    let originalPixelHeight: Int
    let jpegByteCount: Int
    let jpegPixelWidth: Int
    let jpegPixelHeight: Int
    let jpegData: Data?
    let errorDescription: String?
}

/// Captures exactly one display (cursor display when possible) for vision diagnostics.
enum DexterOneScreenImageCapture {
    static func captureOneScreenImage() async -> DexterOneScreenImageCaptureResult {
        let permissionGranted = CGPreflightScreenCaptureAccess()
        if DexterDeveloperModeSettings.isDeveloperModeEnabled {
            print("[SCREEN-RAW] permission=\(permissionGranted)")
        }

        guard permissionGranted else {
            return DexterOneScreenImageCaptureResult(
                permissionGranted: false,
                displayID: nil,
                originalPixelWidth: 0,
                originalPixelHeight: 0,
                jpegByteCount: 0,
                jpegPixelWidth: 0,
                jpegPixelHeight: 0,
                jpegData: nil,
                errorDescription: "CGPreflightScreenCaptureAccess returned false"
            )
        }

        do {
            if DexterDeveloperModeSettings.isDeveloperModeEnabled {
                print("[SCREEN-RAW] capture started")
            }
            let captures = try await CompanionScreenCaptureUtility.captureCursorDisplayAsJPEG(
                pointerLocationInScreenSpace: NSEvent.mouseLocation
            )
            guard let capture = captures.first else {
                return failureResult(permissionGranted: true, error: "No display captured")
            }

            let encodedJPEG: Data
            if let resized = DexterContextImageEncoder.jpegDataForVisionModel(from: capture.imageData) {
                encodedJPEG = resized
            } else {
                encodedJPEG = capture.imageData
            }

            guard !encodedJPEG.isEmpty else {
                return failureResult(permissionGranted: true, error: "JPEG encoding produced empty data")
            }

            let displayID = displayIDForFrame(capture.displayFrame)
            if DexterDeveloperModeSettings.isDeveloperModeEnabled {
                print("[SCREEN-RAW] capture completed")
                print("[SCREEN-RAW] dimensions=\(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels)")
                print("[SCREEN-RAW] JPEG bytes=\(encodedJPEG.count)")
                print("[SCREEN] display=\(displayID.map(String.init) ?? "unknown")")
            }

            return DexterOneScreenImageCaptureResult(
                permissionGranted: true,
                displayID: displayID,
                originalPixelWidth: capture.screenshotWidthInPixels,
                originalPixelHeight: capture.screenshotHeightInPixels,
                jpegByteCount: encodedJPEG.count,
                jpegPixelWidth: capture.screenshotWidthInPixels,
                jpegPixelHeight: capture.screenshotHeightInPixels,
                jpegData: encodedJPEG,
                errorDescription: nil
            )
        } catch {
            print("[SCREEN] capture failed: \(error.localizedDescription)")
            return failureResult(permissionGranted: true, error: error.localizedDescription)
        }
    }

    private static func failureResult(permissionGranted: Bool, error: String) -> DexterOneScreenImageCaptureResult {
        DexterOneScreenImageCaptureResult(
            permissionGranted: permissionGranted,
            displayID: nil,
            originalPixelWidth: 0,
            originalPixelHeight: 0,
            jpegByteCount: 0,
            jpegPixelWidth: 0,
            jpegPixelHeight: 0,
            jpegData: nil,
            errorDescription: error
        )
    }

    private static func displayIDForFrame(_ frame: CGRect) -> UInt32? {
        for screen in NSScreen.screens {
            if screen.frame == frame,
               let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                return screenNumber
            }
        }
        return nil
    }
}
