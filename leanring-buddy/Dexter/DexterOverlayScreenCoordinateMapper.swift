//
//  DexterOverlayScreenCoordinateMapper.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

/// Maps AppKit global screen geometry to overlay SwiftUI coordinates (top-left per display).
enum DexterOverlayScreenCoordinateMapper {
    static func overlayPoint(
        appKitGlobalPoint: CGPoint,
        displayFrameInScreenSpace: CGRect
    ) -> CGPoint {
        CGPoint(
            x: appKitGlobalPoint.x - displayFrameInScreenSpace.origin.x,
            y: displayFrameInScreenSpace.maxY - appKitGlobalPoint.y
        )
    }

    static func overlayRect(
        appKitGlobalRect: CGRect,
        displayFrameInScreenSpace: CGRect
    ) -> CGRect {
        let topLeft = overlayPoint(
            appKitGlobalPoint: CGPoint(x: appKitGlobalRect.minX, y: appKitGlobalRect.maxY),
            displayFrameInScreenSpace: displayFrameInScreenSpace
        )
        let bottomRight = overlayPoint(
            appKitGlobalPoint: CGPoint(x: appKitGlobalRect.maxX, y: appKitGlobalRect.minY),
            displayFrameInScreenSpace: displayFrameInScreenSpace
        )
        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
    }

    /// Converts model screenshot pixel coords to AppKit global point (same math as CompanionManager pointing).
    static func appKitGlobalPoint(
        screenshotPixelPoint: CGPoint,
        screenshotWidthInPixels: CGFloat,
        screenshotHeightInPixels: CGFloat,
        displayWidthInPoints: CGFloat,
        displayHeightInPoints: CGFloat,
        displayFrameInScreenSpace: CGRect
    ) -> CGPoint {
        let clampedX = max(0, min(screenshotPixelPoint.x, screenshotWidthInPixels))
        let clampedY = max(0, min(screenshotPixelPoint.y, screenshotHeightInPixels))
        let displayLocalX = clampedX * (displayWidthInPoints / screenshotWidthInPixels)
        let displayLocalY = clampedY * (displayHeightInPoints / screenshotHeightInPixels)
        let appKitY = displayHeightInPoints - displayLocalY
        return CGPoint(
            x: displayLocalX + displayFrameInScreenSpace.origin.x,
            y: appKitY + displayFrameInScreenSpace.origin.y
        )
    }
}
