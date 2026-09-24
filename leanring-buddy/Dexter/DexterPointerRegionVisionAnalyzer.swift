//
//  DexterPointerRegionVisionAnalyzer.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

protocol DexterPointerRegionVisionAnalyzing {
    func analyze(
        screenshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> DexterPointerVisionAnalysisResult
}

/// Lightweight local vision hints (dominant color) on the pointer attention region — not a second screen recorder.
struct DexterPointerRegionVisionAnalyzer: DexterPointerRegionVisionAnalyzing {
    func analyze(
        screenshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> DexterPointerVisionAnalysisResult {
        guard let pointerPixels = attentionContext.pointerLocationInPrimaryScreenshotPixels else {
            return DexterPointerVisionAnalysisResult(
                appearanceDescription: nil,
                isPredominantlyRed: false,
                availability: .notApplicable
            )
        }

        let smallRegion = CGRect(
            x: pointerPixels.xInPixels - 12,
            y: pointerPixels.yInPixels - 12,
            width: 24,
            height: 24
        )

        guard let croppedImage = DexterPointerScreenshotRegionCropper.cgImage(
            from: screenshot,
            regionInScreenshotPixels: smallRegion
        ) else {
            return DexterPointerVisionAnalysisResult(
                appearanceDescription: nil,
                isPredominantlyRed: false,
                availability: .unavailable(errorDescription: "Could not sample pixels at pointer.")
            )
        }

        let averageColor = averageColor(in: croppedImage)
        let description = DexterPointerColorDescription.describe(averageColor)
        let isPredominantlyRed = DexterPointerColorDescription.isPredominantlyRed(averageColor)

        return DexterPointerVisionAnalysisResult(
            appearanceDescription: description,
            isPredominantlyRed: isPredominantlyRed,
            availability: description == nil ? .notApplicable : .available
        )
    }

    private func averageColor(in image: CGImage) -> NSColor? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelBuffer = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalRed: Double = 0
        var totalGreen: Double = 0
        var totalBlue: Double = 0
        let pixelCount = width * height

        for index in 0..<pixelCount {
            let offset = index * bytesPerPixel
            totalRed += Double(pixelBuffer[offset])
            totalGreen += Double(pixelBuffer[offset + 1])
            totalBlue += Double(pixelBuffer[offset + 2])
        }

        return NSColor(
            red: totalRed / Double(pixelCount) / 255.0,
            green: totalGreen / Double(pixelCount) / 255.0,
            blue: totalBlue / Double(pixelCount) / 255.0,
            alpha: 1
        )
    }
}

enum DexterPointerColorDescription {
    static func isPredominantlyRed(_ color: NSColor?) -> Bool {
        guard let rgb = color?.usingColorSpace(.deviceRGB) else { return false }
        return rgb.redComponent > 0.55
            && rgb.redComponent > rgb.greenComponent + 0.15
            && rgb.redComponent > rgb.blueComponent + 0.15
    }

    static func describe(_ color: NSColor?) -> String? {
        guard let rgb = color?.usingColorSpace(.deviceRGB) else { return nil }
        if isPredominantlyRed(rgb) {
            return "red-toned at pointer"
        }
        if rgb.greenComponent > 0.5 && rgb.greenComponent > rgb.redComponent + 0.1 {
            return "green-toned at pointer"
        }
        if rgb.blueComponent > 0.5 && rgb.blueComponent > rgb.redComponent + 0.1 {
            return "blue-toned at pointer"
        }
        let brightness = (rgb.redComponent + rgb.greenComponent + rgb.blueComponent) / 3.0
        if brightness > 0.85 {
            return "light-colored at pointer"
        }
        if brightness < 0.2 {
            return "dark-colored at pointer"
        }
        return "neutral-toned at pointer"
    }
}
