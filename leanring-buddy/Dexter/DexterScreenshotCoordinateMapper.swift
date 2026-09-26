//
//  DexterScreenshotCoordinateMapper.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterScreenshotCoordinateMapper {
    /// Maps a rectangle in screenshot pixel space (top-left origin) to screen-space center (macOS bottom-left origin).
    static func centerInScreenSpace(
        rectInScreenshotPixels: CGRect,
        screenshot: DexterScreenCaptureSnapshot
    ) -> CGPoint? {
        let displayWidthInPoints = CGFloat(screenshot.displayWidthInPoints)
        let displayHeightInPoints = CGFloat(screenshot.displayHeightInPoints)
        let screenshotWidthInPixels = CGFloat(screenshot.screenshotWidthInPixels)
        let screenshotHeightInPixels = CGFloat(screenshot.screenshotHeightInPixels)

        guard displayWidthInPoints > 0,
              displayHeightInPoints > 0,
              screenshotWidthInPixels > 0,
              screenshotHeightInPixels > 0 else {
            return nil
        }

        let centerXInPixels = rectInScreenshotPixels.midX
        let centerYInPixels = rectInScreenshotPixels.midY

        let displayLocalX = centerXInPixels * (displayWidthInPoints / screenshotWidthInPixels)
        let yTopOriginInPoints = centerYInPixels * (displayHeightInPoints / screenshotHeightInPixels)
        let displayLocalY = displayHeightInPoints - yTopOriginInPoints

        return CGPoint(
            x: screenshot.displayFrame.origin.x + displayLocalX,
            y: screenshot.displayFrame.origin.y + displayLocalY
        )
    }
}
