//
//  DexterVisionUITargetLocalization.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

struct DexterVisionUITargetLocalizationResult: Equatable {
    let found: Bool
    let boundingBoxNormalizedTopLeft: CGRect?
    let confidence: Double?
}

enum DexterVisionUITargetLocalization {
    static let systemPromptSupplement = """
    You locate UI controls in screenshots for computer automation. You do not chat.

    Respond with a single JSON object only (no markdown, no prose):
    {"uiTarget":{"found":true,"boundingBox":{"x":0.0,"y":0.0,"width":0.0,"height":0.0},"confidence":0.0}}

    Rules:
    - boundingBox uses normalized coordinates (0–1) with origin at the TOP-LEFT of the image.
    - x,y are the top-left corner of the control; width and height are positive fractions of image size.
    - If the control is not clearly visible, return found=false and null boundingBox.
    - Do not invent controls that are not visible.
    """

    static func userQuestion(
        destinationLabel: String,
        applicationName: String?,
        observationId: String
    ) -> String {
        let applicationPhrase = applicationName.map { " in the \($0) window" } ?? " in the current window"
        return """
        Locate the UI control corresponding to "\(destinationLabel)"\(applicationPhrase).
        observationId=\(observationId)
        Return JSON only.
        """
    }

    static func parse(rawText: String) -> DexterVisionUITargetLocalizationResult {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonStart = trimmed.firstIndex(of: "{"),
              let jsonEnd = trimmed.lastIndex(of: "}") else {
            return DexterVisionUITargetLocalizationResult(found: false, boundingBoxNormalizedTopLeft: nil, confidence: nil)
        }
        let jsonSlice = String(trimmed[jsonStart...jsonEnd])
        guard let data = jsonSlice.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uiTarget = object["uiTarget"] as? [String: Any] else {
            return DexterVisionUITargetLocalizationResult(found: false, boundingBoxNormalizedTopLeft: nil, confidence: nil)
        }

        let found = (uiTarget["found"] as? Bool) ?? false
        let confidence = uiTarget["confidence"] as? Double
        guard found, let box = uiTarget["boundingBox"] as? [String: Any] else {
            return DexterVisionUITargetLocalizationResult(found: false, boundingBoxNormalizedTopLeft: nil, confidence: confidence)
        }

        guard let x = doubleValue(box["x"]),
              let y = doubleValue(box["y"]),
              let width = doubleValue(box["width"]),
              let height = doubleValue(box["height"]),
              width > 0,
              height > 0 else {
            return DexterVisionUITargetLocalizationResult(found: false, boundingBoxNormalizedTopLeft: nil, confidence: confidence)
        }

        return DexterVisionUITargetLocalizationResult(
            found: true,
            boundingBoxNormalizedTopLeft: CGRect(x: x, y: y, width: width, height: height),
            confidence: confidence
        )
    }

    static func centerInScreenSpace(
        localization: DexterVisionUITargetLocalizationResult,
        screenshot: DexterScreenCaptureSnapshot
    ) -> CGPoint? {
        guard localization.found, let normalizedBox = localization.boundingBoxNormalizedTopLeft else {
            return nil
        }

        let imageWidth = CGFloat(screenshot.screenshotWidthInPixels)
        let imageHeight = CGFloat(screenshot.screenshotHeightInPixels)
        let rectInScreenshotPixels = CGRect(
            x: normalizedBox.origin.x * imageWidth,
            y: normalizedBox.origin.y * imageHeight,
            width: normalizedBox.size.width * imageWidth,
            height: normalizedBox.size.height * imageHeight
        )
        return DexterScreenshotCoordinateMapper.centerInScreenSpace(
            rectInScreenshotPixels: rectInScreenshotPixels,
            screenshot: screenshot
        )
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String { return Double(stringValue) }
        return nil
    }
}
