//
//  DexterPointerScreenshotRegionCropper.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

enum DexterPointerScreenshotRegionCropper {
    static func cgImage(
        from screenshot: DexterScreenCaptureSnapshot,
        regionInScreenshotPixels: CGRect
    ) -> CGImage? {
        guard let sourceImage = NSImage(data: screenshot.imageData),
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(screenshot.screenshotWidthInPixels),
            height: CGFloat(screenshot.screenshotHeightInPixels)
        )
        let clampedRegion = regionInScreenshotPixels.intersection(bounds)
        guard clampedRegion.width >= 1, clampedRegion.height >= 1 else { return nil }

        return cgImage.cropping(to: clampedRegion)
    }
}
