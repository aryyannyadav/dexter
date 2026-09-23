//
//  ContextProvider.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Builds a `DexterContext` when Dexter needs awareness of the user's environment.
protocol ContextProvider: AnyObject {
    func buildContext(forUserTranscript userTranscript: String) async throws -> DexterContext
}

/// Default provider: multi-monitor screenshots and pointer position.
@MainActor
final class ScreenCaptureContextProvider: ContextProvider {
    func buildContext(forUserTranscript userTranscript: String) async throws -> DexterContext {
        let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
        let snapshots = screenCaptures.map { DexterScreenCaptureSnapshot(companionScreenCapture: $0) }
        return DexterContext(
            screenCaptures: snapshots,
            pointerLocationInScreenSpace: NSEvent.mouseLocation,
            userTranscript: userTranscript
        )
    }
}
