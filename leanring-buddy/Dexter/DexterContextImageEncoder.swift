//
//  DexterContextImageEncoder.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterContextImageEncoder {
    /// Downscales and recompresses JPEG screen captures before sending to a local vision model. Never upscales.
    static func jpegDataForVisionModel(
        from originalJPEGData: Data,
        maxPixelDimension: CGFloat = 1280,
        compressionQuality: CGFloat = 0.72,
        diagnosticReason: String = "vision-model-encode"
    ) -> Data? {
        DexterScreenCaptureDiagnostics.logJPEGConversion(reason: diagnosticReason)
        DexterVisionTiming.markJPEGEncodingStarted()

        guard let sourceBitmap = NSBitmapImageRep(data: originalJPEGData) else {
            return originalJPEGData.isEmpty ? nil : originalJPEGData
        }

        let originalPixelWidth = sourceBitmap.pixelsWide
        let originalPixelHeight = sourceBitmap.pixelsHigh
        let longestPixelSide = max(originalPixelWidth, originalPixelHeight)
        let scaleFactor = min(1.0, maxPixelDimension / CGFloat(max(longestPixelSide, 1)))

        let targetPixelWidth = max(1, Int(floor(CGFloat(originalPixelWidth) * scaleFactor)))
        let targetPixelHeight = max(1, Int(floor(CGFloat(originalPixelHeight) * scaleFactor)))

        let outputBitmap: NSBitmapImageRep
        if scaleFactor >= 1.0 {
            outputBitmap = sourceBitmap
        } else if let resizedBitmap = resizedBitmapRep(
            from: sourceBitmap,
            targetPixelWidth: targetPixelWidth,
            targetPixelHeight: targetPixelHeight
        ) {
            outputBitmap = resizedBitmap
        } else {
            outputBitmap = sourceBitmap
        }

        guard let jpegData = outputBitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        ) else {
            DexterVisionTiming.markJPEGEncodingCompleted(
                originalPixelWidth: originalPixelWidth,
                originalPixelHeight: originalPixelHeight,
                jpegPixelWidth: originalPixelWidth,
                jpegPixelHeight: originalPixelHeight,
                jpegByteCount: originalJPEGData.count,
                base64CharacterCount: originalJPEGData.base64EncodedString().count
            )
            return originalJPEGData
        }

        let base64CharacterCount = jpegData.base64EncodedString().count
        DexterVisionTiming.markJPEGEncodingCompleted(
            originalPixelWidth: originalPixelWidth,
            originalPixelHeight: originalPixelHeight,
            jpegPixelWidth: outputBitmap.pixelsWide,
            jpegPixelHeight: outputBitmap.pixelsHigh,
            jpegByteCount: jpegData.count,
            base64CharacterCount: base64CharacterCount
        )

        return jpegData
    }

    private static func resizedBitmapRep(
        from sourceBitmap: NSBitmapImageRep,
        targetPixelWidth: Int,
        targetPixelHeight: Int
    ) -> NSBitmapImageRep? {
        guard let resizedBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetPixelWidth,
            pixelsHigh: targetPixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: resizedBitmap)
        sourceBitmap.draw(in: NSRect(x: 0, y: 0, width: targetPixelWidth, height: targetPixelHeight))
        NSGraphicsContext.restoreGraphicsState()

        return resizedBitmap
    }
}
