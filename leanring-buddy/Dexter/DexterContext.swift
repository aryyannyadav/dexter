//
//  DexterContext.swift
//  leanring-buddy
//
//  Snapshot of situational data Dexter can use for reasoning and actions.
//

import AppKit
import Foundation

/// A single labeled screen capture included in context.
struct DexterScreenCaptureSnapshot: Equatable {
    let imageData: Data
    let label: String
    let isCursorScreen: Bool
    let displayWidthInPoints: Int
    let displayHeightInPoints: Int
    let displayFrame: CGRect
    let screenshotWidthInPixels: Int
    let screenshotHeightInPixels: Int
}

extension DexterScreenCaptureSnapshot {
    init(companionScreenCapture: CompanionScreenCapture) {
        imageData = companionScreenCapture.imageData
        label = companionScreenCapture.label
        isCursorScreen = companionScreenCapture.isCursorScreen
        displayWidthInPoints = companionScreenCapture.displayWidthInPoints
        displayHeightInPoints = companionScreenCapture.displayHeightInPoints
        displayFrame = companionScreenCapture.displayFrame
        screenshotWidthInPixels = companionScreenCapture.screenshotWidthInPixels
        screenshotHeightInPixels = companionScreenCapture.screenshotHeightInPixels
    }
}

extension CompanionScreenCapture {
    init(snapshot: DexterScreenCaptureSnapshot) {
        self.init(
            imageData: snapshot.imageData,
            label: snapshot.label,
            isCursorScreen: snapshot.isCursorScreen,
            displayWidthInPoints: snapshot.displayWidthInPoints,
            displayHeightInPoints: snapshot.displayHeightInPoints,
            displayFrame: snapshot.displayFrame,
            screenshotWidthInPixels: snapshot.screenshotWidthInPixels,
            screenshotHeightInPixels: snapshot.screenshotHeightInPixels
        )
    }
}

/// Collected context for one Dexter interaction. Fields expand as features are added.
struct DexterContext: Equatable {
    var screenCaptures: [DexterScreenCaptureSnapshot]
    var pointerLocationInScreenSpace: CGPoint?
    var userTranscript: String?

    init(
        screenCaptures: [DexterScreenCaptureSnapshot] = [],
        pointerLocationInScreenSpace: CGPoint? = nil,
        userTranscript: String? = nil
    ) {
        self.screenCaptures = screenCaptures
        self.pointerLocationInScreenSpace = pointerLocationInScreenSpace
        self.userTranscript = userTranscript
    }
}
