//
//  DexterPointerAnalysisPolicy.swift
//  leanring-buddy
//

import Foundation

enum DexterPointerAnalysisPolicy {
    static func accessibilityConfidenceScore(hint: DexterAccessibilityHintAtPointer) -> Double {
        guard hint.availability == .available else { return 0 }

        var score: Double = 0
        if hint.title?.nonEmptyTrimmedValue != nil {
            score += 0.45
        }
        if hint.roleDescription?.nonEmptyTrimmedValue != nil {
            score += 0.2
        }
        if hint.valueDescription?.nonEmptyTrimmedValue != nil {
            score += 0.15
        }
        return min(score, 1.0)
    }

    static func shouldRunOCR(
        accessibilityScore: Double,
        hasScreenshot: Bool
    ) -> Bool {
        guard DexterScreenContextSettingsStore.resolvedOCREnabled else { return false }
        guard hasScreenshot else { return false }
        return accessibilityScore < 0.55
    }

    static func shouldRunVision(
        accessibilityScore: Double,
        ocrResult: DexterPointerOCRAnalysisResult,
        userMessage: String?
    ) -> Bool {
        guard DexterScreenContextSettingsStore.resolvedVisualReasoningEnabled else { return false }
        let normalizedMessage = userMessage?.lowercased() ?? ""
        let asksAboutAppearance = normalizedMessage.contains("why is this red")
            || normalizedMessage.contains("why is that red")
            || normalizedMessage.contains("what color")
            || normalizedMessage.contains("look like")

        if asksAboutAppearance {
            return true
        }

        if accessibilityScore >= 0.55 {
            return false
        }

        let ocrHasText = ocrResult.textAtPointer?.nonEmptyTrimmedValue != nil
            || ocrResult.nearbyText?.nonEmptyTrimmedValue != nil
        return !ocrHasText && accessibilityScore < 0.35
    }
}
