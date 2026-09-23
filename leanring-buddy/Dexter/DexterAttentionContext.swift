//
//  DexterAttentionContext.swift
//  leanring-buddy
//
//  Pointer-as-signal context. Does not assert UI element identity without evidence.
//

import AppKit
import Foundation

struct DexterPointerLocationInScreenshotSpace: Equatable {
    let xInPixels: CGFloat
    let yInPixels: CGFloat
    let screenshotWidthInPixels: Int
    let screenshotHeightInPixels: Int
}

struct DexterPointerRegionInScreenshotSpace: Equatable {
    let rectInPixels: CGRect
}

/// Accessibility-derived hints at the pointer. Informational only — not confirmed UI identity.
struct DexterAccessibilityHintAtPointer: Equatable {
    let roleDescription: String?
    let title: String?
    /// Accessibility value near the pointer (e.g. checkbox on/off) when readable.
    let valueDescription: String?
    let availability: DexterContextAvailability
}

/// Where the user's attention likely is based on pointer position and capture geometry.
struct DexterAttentionContext: Equatable {
    let pointerLocationInScreenSpace: CGPoint
    let pointerLocationRelativeToDisplay: CGPoint?
    let regionAroundPointerInScreenSpace: CGRect?
    let pointerLocationInPrimaryScreenshotPixels: DexterPointerLocationInScreenshotSpace?
    let regionAroundPointerInPrimaryScreenshotPixels: DexterPointerRegionInScreenshotSpace?
    let accessibilityHintAtPointer: DexterAccessibilityHintAtPointer
    let primaryDisplayIdentifier: UInt32?
}

enum DexterPointerAttentionCalculator {
    static let defaultRegionRadiusInPoints: CGFloat = 160

    static func pointerLocationRelativeToDisplay(
        pointerLocationInScreenSpace: CGPoint,
        displayFrameInScreenSpace: CGRect
    ) -> CGPoint {
        CGPoint(
            x: pointerLocationInScreenSpace.x - displayFrameInScreenSpace.origin.x,
            y: pointerLocationInScreenSpace.y - displayFrameInScreenSpace.origin.y
        )
    }

    static func regionAroundPointerInScreenSpace(
        pointerLocationInScreenSpace: CGPoint,
        displayFrameInScreenSpace: CGRect,
        regionRadiusInPoints: CGFloat = defaultRegionRadiusInPoints
    ) -> CGRect {
        let unclampedRegion = CGRect(
            x: pointerLocationInScreenSpace.x - regionRadiusInPoints,
            y: pointerLocationInScreenSpace.y - regionRadiusInPoints,
            width: regionRadiusInPoints * 2,
            height: regionRadiusInPoints * 2
        )
        return unclampedRegion.intersection(displayFrameInScreenSpace)
    }

    /// Maps pointer from AppKit display coordinates (bottom-left origin) to screenshot pixels (top-left origin).
    static func pointerLocationInScreenshotPixels(
        pointerLocationInScreenSpace: CGPoint,
        displayFrameInScreenSpace: CGRect,
        displayWidthInPoints: CGFloat,
        displayHeightInPoints: CGFloat,
        screenshotWidthInPixels: CGFloat,
        screenshotHeightInPixels: CGFloat
    ) -> DexterPointerLocationInScreenshotSpace? {
        guard displayWidthInPoints > 0, displayHeightInPoints > 0,
              screenshotWidthInPixels > 0, screenshotHeightInPixels > 0 else {
            return nil
        }

        let displayLocalX = pointerLocationInScreenSpace.x - displayFrameInScreenSpace.origin.x
        let displayLocalY = pointerLocationInScreenSpace.y - displayFrameInScreenSpace.origin.y

        guard displayLocalX >= 0, displayLocalY >= 0,
              displayLocalX <= displayWidthInPoints, displayLocalY <= displayHeightInPoints else {
            return nil
        }

        let xInPixels = displayLocalX * (screenshotWidthInPixels / displayWidthInPoints)
        let yTopOriginInPoints = displayHeightInPoints - displayLocalY
        let yInPixels = yTopOriginInPoints * (screenshotHeightInPixels / displayHeightInPoints)

        return DexterPointerLocationInScreenshotSpace(
            xInPixels: xInPixels,
            yInPixels: yInPixels,
            screenshotWidthInPixels: Int(screenshotWidthInPixels),
            screenshotHeightInPixels: Int(screenshotHeightInPixels)
        )
    }

    static func regionAroundPointerInScreenshotPixels(
        pointerLocationInScreenshotPixels: DexterPointerLocationInScreenshotSpace,
        regionRadiusInScreenshotPixels: CGFloat
    ) -> DexterPointerRegionInScreenshotSpace {
        let screenshotWidth = CGFloat(pointerLocationInScreenshotPixels.screenshotWidthInPixels)
        let screenshotHeight = CGFloat(pointerLocationInScreenshotPixels.screenshotHeightInPixels)

        let unclampedRegion = CGRect(
            x: pointerLocationInScreenshotPixels.xInPixels - regionRadiusInScreenshotPixels,
            y: pointerLocationInScreenshotPixels.yInPixels - regionRadiusInScreenshotPixels,
            width: regionRadiusInScreenshotPixels * 2,
            height: regionRadiusInScreenshotPixels * 2
        )

        let screenshotBounds = CGRect(x: 0, y: 0, width: screenshotWidth, height: screenshotHeight)
        return DexterPointerRegionInScreenshotSpace(rectInPixels: unclampedRegion.intersection(screenshotBounds))
    }

    static func buildAttentionContext(
        pointerLocationInScreenSpace: CGPoint,
        display: DexterDisplayContext?,
        primaryScreenshot: DexterScreenCaptureSnapshot?,
        accessibilityHintAtPointer: DexterAccessibilityHintAtPointer,
        regionRadiusInPoints: CGFloat = defaultRegionRadiusInPoints
    ) -> DexterAttentionContext {
        let displayFrame = display?.displayFrameInScreenSpace
        let pointerRelativeToDisplay: CGPoint?
        let regionInScreenSpace: CGRect?

        if let displayFrame {
            pointerRelativeToDisplay = pointerLocationRelativeToDisplay(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                displayFrameInScreenSpace: displayFrame
            )
            regionInScreenSpace = regionAroundPointerInScreenSpace(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                displayFrameInScreenSpace: displayFrame,
                regionRadiusInPoints: regionRadiusInPoints
            )
        } else {
            pointerRelativeToDisplay = nil
            regionInScreenSpace = nil
        }

        var pointerInScreenshotPixels: DexterPointerLocationInScreenshotSpace?
        var regionInScreenshotPixels: DexterPointerRegionInScreenshotSpace?

        if let primaryScreenshot, let displayFrame {
            pointerInScreenshotPixels = pointerLocationInScreenshotPixels(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                displayFrameInScreenSpace: displayFrame,
                displayWidthInPoints: CGFloat(primaryScreenshot.displayWidthInPoints),
                displayHeightInPoints: CGFloat(primaryScreenshot.displayHeightInPoints),
                screenshotWidthInPixels: CGFloat(primaryScreenshot.screenshotWidthInPixels),
                screenshotHeightInPixels: CGFloat(primaryScreenshot.screenshotHeightInPixels)
            )

            if let pointerInScreenshotPixels {
                let scale = CGFloat(primaryScreenshot.screenshotWidthInPixels) / CGFloat(primaryScreenshot.displayWidthInPoints)
                let regionRadiusInScreenshotPixels = regionRadiusInPoints * scale
                regionInScreenshotPixels = regionAroundPointerInScreenshotPixels(
                    pointerLocationInScreenshotPixels: pointerInScreenshotPixels,
                    regionRadiusInScreenshotPixels: regionRadiusInScreenshotPixels
                )
            }
        }

        return DexterAttentionContext(
            pointerLocationInScreenSpace: pointerLocationInScreenSpace,
            pointerLocationRelativeToDisplay: pointerRelativeToDisplay,
            regionAroundPointerInScreenSpace: regionInScreenSpace,
            pointerLocationInPrimaryScreenshotPixels: pointerInScreenshotPixels,
            regionAroundPointerInPrimaryScreenshotPixels: regionInScreenshotPixels,
            accessibilityHintAtPointer: accessibilityHintAtPointer,
            primaryDisplayIdentifier: display?.displayIdentifier
        )
    }
}
