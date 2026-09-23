//
//  DexterScreenCaptureProviding.swift
//  leanring-buddy
//

import Foundation

/// Abstraction over on-demand screen capture (invoked only per Dexter interaction).
protocol DexterScreenCaptureProviding: AnyObject {
    func captureScreensForPointerAttention(pointerLocationInScreenSpace: CGPoint) async throws -> [CompanionScreenCapture]
}

@MainActor
final class CompanionScreenCaptureProvider: DexterScreenCaptureProviding {
    func captureScreensForPointerAttention(pointerLocationInScreenSpace: CGPoint) async throws -> [CompanionScreenCapture] {
        try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG(
            pointerLocationInScreenSpace: pointerLocationInScreenSpace
        )
    }
}
