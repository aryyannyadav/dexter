//
//  DexterPointerRegionOCRAnalyzer.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation
import Vision

protocol DexterPointerRegionOCRAnalyzing {
    func analyze(
        screenshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> DexterPointerOCRAnalysisResult
}

/// OCR on the attention region around the pointer (uses existing on-demand capture only).
struct DexterVisionPointerRegionOCRAnalyzer: DexterPointerRegionOCRAnalyzing {
    func analyze(
        screenshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> DexterPointerOCRAnalysisResult {
        guard let pointerPixels = attentionContext.pointerLocationInPrimaryScreenshotPixels else {
            return DexterPointerOCRAnalysisResult(
                textAtPointer: nil,
                nearbyText: nil,
                availability: .notApplicable
            )
        }

        let region = attentionContext.regionAroundPointerInPrimaryScreenshotPixels?.rectInPixels
            ?? CGRect(
                x: pointerPixels.xInPixels - 80,
                y: pointerPixels.yInPixels - 40,
                width: 160,
                height: 80
            )

        guard let croppedImage = DexterPointerScreenshotRegionCropper.cgImage(
            from: screenshot,
            regionInScreenshotPixels: region
        ) else {
            return DexterPointerOCRAnalysisResult(
                textAtPointer: nil,
                nearbyText: nil,
                availability: .unavailable(errorDescription: "Could not crop attention region for OCR.")
            )
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: croppedImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return DexterPointerOCRAnalysisResult(
                textAtPointer: nil,
                nearbyText: nil,
                availability: .unavailable(errorDescription: "OCR failed.")
            )
        }

        let observations = request.results ?? []
        let pointerPoint = CGPoint(x: pointerPixels.xInPixels, y: pointerPixels.yInPixels)
        let regionOrigin = region.origin

        var textAtPointer: String?
        var nearbyCandidates: [String] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let boundingBox = observation.boundingBox
            let rectInCroppedSpace = CGRect(
                x: boundingBox.origin.x * region.width,
                y: (1.0 - boundingBox.origin.y - boundingBox.size.height) * region.height,
                width: boundingBox.size.width * region.width,
                height: boundingBox.size.height * region.height
            )
            let rectInScreenshotSpace = rectInCroppedSpace.offsetBy(dx: regionOrigin.x, dy: regionOrigin.y)

            if rectInScreenshotSpace.contains(pointerPoint) {
                textAtPointer = text
            } else if rectInScreenshotSpace.insetBy(dx: -24, dy: -24).contains(pointerPoint) {
                nearbyCandidates.append(text)
            }
        }

        if textAtPointer == nil, let firstNearby = nearbyCandidates.first {
            textAtPointer = firstNearby
        }

        let nearbyText = nearbyCandidates.isEmpty ? nil : nearbyCandidates.prefix(3).joined(separator: " | ")

        if textAtPointer == nil && nearbyText == nil {
            return DexterPointerOCRAnalysisResult(
                textAtPointer: nil,
                nearbyText: nil,
                availability: .notApplicable
            )
        }

        return DexterPointerOCRAnalysisResult(
            textAtPointer: textAtPointer,
            nearbyText: nearbyText,
            availability: .available
        )
    }
}
