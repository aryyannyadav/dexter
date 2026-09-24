//
//  DexterScreenCaptureProviding.swift
//  leanring-buddy
//

import Foundation

enum DexterScreenCaptureScope: Equatable {
    case allDisplays
    case cursorDisplayOnly
}

/// Abstraction over on-demand screen capture (invoked only per Dexter interaction).
protocol DexterScreenCaptureProviding: AnyObject {
    func captureScreensForPointerAttention(
        pointerLocationInScreenSpace: CGPoint,
        scope: DexterScreenCaptureScope,
        diagnosticReason: String
    ) async throws -> [CompanionScreenCapture]
}

@MainActor
final class CompanionScreenCaptureProvider: DexterScreenCaptureProviding {
    func captureScreensForPointerAttention(
        pointerLocationInScreenSpace: CGPoint,
        scope: DexterScreenCaptureScope,
        diagnosticReason: String = "visual-request"
    ) async throws -> [CompanionScreenCapture] {
        switch scope {
        case .allDisplays:
            return try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                diagnosticReason: diagnosticReason
            )
        case .cursorDisplayOnly:
            return try await CompanionScreenCaptureUtility.captureCursorDisplayAsJPEG(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                diagnosticReason: diagnosticReason
            )
        }
    }
}
