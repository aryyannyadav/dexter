//
//  DexterScreenOCRDestinationLocator.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation
import ImageIO
import Vision

enum DexterScreenOCRDestinationLocator {
    struct OCRTextObservation: Equatable {
        let text: String
        let rectInScreenshotPixels: CGRect
    }

    static func locateCenterInScreenSpace(
        destinationLabel: String,
        screenshot: DexterScreenCaptureSnapshot
    ) -> CGPoint? {
        guard let matchRect = bestMatchingTextRect(
            destinationLabel: destinationLabel,
            screenshot: screenshot
        ) else {
            return nil
        }
        return DexterScreenshotCoordinateMapper.centerInScreenSpace(
            rectInScreenshotPixels: matchRect,
            screenshot: screenshot
        )
    }

    static func bestMatchingTextRect(
        destinationLabel: String,
        screenshot: DexterScreenCaptureSnapshot
    ) -> CGRect? {
        let observations = recognizeTextObservations(on: screenshot)
        guard !observations.isEmpty else { return nil }

        let normalizedDestination = DexterUserInterfaceDestinationTextMatcher.normalize(destinationLabel)
        guard !normalizedDestination.isEmpty else { return nil }

        if let exact = observations.first(where: {
            DexterUserInterfaceDestinationTextMatcher.normalize($0.text) == normalizedDestination
        }) {
            return exact.rectInScreenshotPixels
        }

        if let contains = observations.first(where: {
            DexterUserInterfaceDestinationTextMatcher.normalize($0.text).contains(normalizedDestination)
            || normalizedDestination.contains(DexterUserInterfaceDestinationTextMatcher.normalize($0.text))
        }) {
            return contains.rectInScreenshotPixels
        }

        let destinationTokens = normalizedDestination.split(separator: " ").map(String.init)
        if destinationTokens.count > 1 {
            if let merged = mergedRectMatchingSequentialTokens(
                destinationTokens: destinationTokens,
                observations: observations
            ) {
                return merged
            }
        }

        return nil
    }

    private static func recognizeTextObservations(
        on screenshot: DexterScreenCaptureSnapshot
    ) -> [OCRTextObservation] {
        guard let cgImage = cgImage(fromJPEGData: screenshot.imageData) else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let imageWidth = CGFloat(screenshot.screenshotWidthInPixels)
        let imageHeight = CGFloat(screenshot.screenshotHeightInPixels)
        guard imageWidth > 0, imageHeight > 0 else { return [] }

        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }

            let boundingBox = observation.boundingBox
            let rectInScreenshotPixels = CGRect(
                x: boundingBox.origin.x * imageWidth,
                y: (1.0 - boundingBox.origin.y - boundingBox.size.height) * imageHeight,
                width: boundingBox.size.width * imageWidth,
                height: boundingBox.size.height * imageHeight
            )
            return OCRTextObservation(text: text, rectInScreenshotPixels: rectInScreenshotPixels)
        }
    }

    private static func mergedRectMatchingSequentialTokens(
        destinationTokens: [String],
        observations: [OCRTextObservation]
    ) -> CGRect? {
        let normalizedObservations = observations.map {
            (
                text: DexterUserInterfaceDestinationTextMatcher.normalize($0.text),
                rect: $0.rectInScreenshotPixels
            )
        }

        for startIndex in 0..<normalizedObservations.count {
            var matchedRects: [CGRect] = []
            var tokenIndex = 0
            for observationIndex in startIndex..<normalizedObservations.count {
                let observationText = normalizedObservations[observationIndex].text
                guard tokenIndex < destinationTokens.count else { break }
                let token = destinationTokens[tokenIndex]
                if observationText == token || observationText.contains(token) {
                    matchedRects.append(normalizedObservations[observationIndex].rect)
                    tokenIndex += 1
                    if tokenIndex == destinationTokens.count {
                        return unionRect(of: matchedRects)
                    }
                }
            }
        }
        return nil
    }

    private static func unionRect(of rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    private static func cgImage(fromJPEGData imageData: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

enum DexterUserInterfaceDestinationTextMatcher {
    static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
