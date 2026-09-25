//
//  DexterScreenCaptureDiagnostics.swift
//  leanring-buddy
//

import Foundation

enum DexterScreenCaptureDiagnostics {
    static func logCaptureStart(reason: String) {
        DexterTurnTrace.log("SCREEN CAPTURE START reason=\(reason)")
        if DexterDeveloperModeSettings.isDeveloperModeEnabled {
            print("[SCREEN-CAPTURE-START] reason=\(reason)")
        }
    }

    static func logCaptureComplete(reason: String, imageCount: Int) {
        DexterTurnTrace.log("SCREEN CAPTURE COMPLETE reason=\(reason) images=\(imageCount)")
    }

    static func logJPEGConversion(reason: String) {
        DexterTurnTrace.log("JPEG COMPLETE reason=\(reason)")
        if DexterDeveloperModeSettings.isDeveloperModeEnabled {
            print("[SCREEN-JPEG] reason=\(reason)")
        }
    }
}
