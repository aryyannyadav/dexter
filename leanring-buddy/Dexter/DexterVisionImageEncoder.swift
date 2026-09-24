//
//  DexterVisionImageEncoder.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

enum DexterVisionImageEncoder {
    /// Matches working ScreenCaptureKit output (long edge 1280). Never upscales.
    static let visionMaxPixelDimension: CGFloat = 1280

    static func encodedJPEG(
        from snapshot: DexterScreenCaptureSnapshot,
        scope: DexterVisionImageScope,
        attentionContext: DexterAttentionContext
    ) -> Data? {
        switch scope {
        case .fullScreen:
            return DexterContextImageEncoder.jpegDataForVisionModel(
                from: snapshot.imageData,
                maxPixelDimension: visionMaxPixelDimension,
                diagnosticReason: "vision-full-screen"
            )
        case .pointerCrop, .relevantRegion:
            guard let cropRegion = cropRegionInScreenshotPixels(
                scope: scope,
                snapshot: snapshot,
                attentionContext: attentionContext
            ) else {
                return DexterContextImageEncoder.jpegDataForVisionModel(
                    from: snapshot.imageData,
                    maxPixelDimension: visionMaxPixelDimension,
                    diagnosticReason: "vision-scope-fallback-full"
                )
            }

            guard let croppedImage = DexterPointerScreenshotRegionCropper.cgImage(
                from: snapshot,
                regionInScreenshotPixels: cropRegion
            ) else {
                return nil
            }

            guard let croppedJPEG = jpegData(from: croppedImage, compressionQuality: 0.72) else {
                return nil
            }

            return DexterContextImageEncoder.jpegDataForVisionModel(
                from: croppedJPEG,
                maxPixelDimension: visionMaxPixelDimension,
                diagnosticReason: "vision-\(scope.rawValue)"
            )
        }
    }

    static func pixelDimensions(of jpegData: Data) -> (width: Int, height: Int)? {
        guard let bitmap = NSBitmapImageRep(data: jpegData) else { return nil }
        return (bitmap.pixelsWide, bitmap.pixelsHigh)
    }

    private static func cropRegionInScreenshotPixels(
        scope: DexterVisionImageScope,
        snapshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> CGRect? {
        guard let pointerPixels = attentionContext.pointerLocationInPrimaryScreenshotPixels else {
            return nil
        }

        switch scope {
        case .fullScreen:
            return nil
        case .relevantRegion:
            if let region = attentionContext.regionAroundPointerInPrimaryScreenshotPixels?.rectInPixels {
                return region
            }
            return defaultRegionAround(
                pointerX: pointerPixels.xInPixels,
                pointerY: pointerPixels.yInPixels,
                radiusX: 200,
                radiusY: 140,
                snapshot: snapshot
            )
        case .pointerCrop:
            return defaultRegionAround(
                pointerX: pointerPixels.xInPixels,
                pointerY: pointerPixels.yInPixels,
                radiusX: 120,
                radiusY: 72,
                snapshot: snapshot
            )
        }
    }

    private static func defaultRegionAround(
        pointerX: CGFloat,
        pointerY: CGFloat,
        radiusX: CGFloat,
        radiusY: CGFloat,
        snapshot: DexterScreenCaptureSnapshot
    ) -> CGRect {
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(snapshot.screenshotWidthInPixels),
            height: CGFloat(snapshot.screenshotHeightInPixels)
        )
        let unclamped = CGRect(
            x: pointerX - radiusX,
            y: pointerY - radiusY,
            width: radiusX * 2,
            height: radiusY * 2
        )
        return unclamped.intersection(bounds)
    }

    private static func jpegData(from cgImage: CGImage, compressionQuality: CGFloat) -> Data? {
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
