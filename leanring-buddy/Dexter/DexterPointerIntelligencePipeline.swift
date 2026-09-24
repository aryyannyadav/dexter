//
//  DexterPointerIntelligencePipeline.swift
//  leanring-buddy
//
//  mouse position → display → window → application → region → AX → OCR → vision → semantic target
//

import Foundation

enum DexterPointerIntelligencePipeline {
    static func buildPointerContext(
        input: DexterPointerIntelligencePipelineInput,
        ocrAnalyzer: DexterPointerRegionOCRAnalyzing = DexterVisionPointerRegionOCRAnalyzer(),
        visionAnalyzer: DexterPointerRegionVisionAnalyzing = DexterPointerRegionVisionAnalyzer()
    ) -> DexterPointerContext {
        let pointerStartedAt = Date()

        let accessibilityScore = DexterPointerAnalysisPolicy.accessibilityConfidenceScore(
            hint: input.accessibilityHintAtPointer
        )

        let ocrResult: DexterPointerOCRAnalysisResult
        if DexterPointerAnalysisPolicy.shouldRunOCR(
            accessibilityScore: accessibilityScore,
            hasScreenshot: input.primaryScreenshot != nil
        ), let primaryScreenshot = input.primaryScreenshot {
            ocrResult = DexterPerformanceTiming.measureSync(bucket: .ocr, detail: "pointer_region") {
                ocrAnalyzer.analyze(screenshot: primaryScreenshot, attentionContext: input.attentionContext)
            }
        } else {
            ocrResult = DexterPointerOCRAnalysisResult(
                textAtPointer: nil,
                nearbyText: nil,
                availability: .notApplicable
            )
            if input.primaryScreenshot != nil {
                DexterObservabilityLog.perf("ocr_skipped accessibility_score=\(String(format: "%.2f", accessibilityScore))")
            }
        }

        let visionResult: DexterPointerVisionAnalysisResult
        if DexterPointerAnalysisPolicy.shouldRunVision(
            accessibilityScore: accessibilityScore,
            ocrResult: ocrResult,
            userMessage: input.userMessage
        ), let primaryScreenshot = input.primaryScreenshot {
            visionResult = DexterPerformanceTiming.measureSync(bucket: .vision, detail: "pointer_region") {
                visionAnalyzer.analyze(screenshot: primaryScreenshot, attentionContext: input.attentionContext)
            }
        } else {
            visionResult = DexterPointerVisionAnalysisResult(
                appearanceDescription: nil,
                isPredominantlyRed: false,
                availability: .notApplicable
            )
            DexterObservabilityLog.perf("vision_skipped accessibility_score=\(String(format: "%.2f", accessibilityScore))")
        }

        let semanticTarget = DexterPointerSemanticTargetResolver.resolve(
            accessibilityHint: input.accessibilityHintAtPointer,
            activeApplication: input.activeApplication,
            activeWindow: input.activeWindow,
            ocrResult: ocrResult,
            visionResult: visionResult,
            elementLocationCorroboratesPointer: input.elementLocationCorroboratesPointer
        )

        let pointerMilliseconds = Int(Date().timeIntervalSince(pointerStartedAt) * 1000)
        DexterTaskTraceRecorder.shared.recordLatency(bucket: .pointerDetection, milliseconds: pointerMilliseconds)

        return DexterPointerContext(
            screenDisplayIdentifier: input.display?.displayIdentifier ?? input.attentionContext.primaryDisplayIdentifier,
            locationInScreenSpace: input.pointerLocationInScreenSpace,
            capturedAt: input.capturedAt,
            activeApplication: input.activeApplication,
            activeWindow: input.activeWindow,
            semanticTarget: semanticTarget,
            confidence: semanticTarget.confidence,
            attentionRegionInScreenSpace: input.attentionContext.regionAroundPointerInScreenSpace
        )
    }

    static func buildPointerTargetContext(
        from pointerContext: DexterPointerContext,
        accessibilityHintAtPointer: DexterAccessibilityHintAtPointer
    ) -> DexterPointerTargetContext? {
        guard let semanticTarget = pointerContext.semanticTarget else { return nil }
        return DexterPointerTargetContext(
            semanticTarget: semanticTarget,
            accessibilityHintAtPointer: accessibilityHintAtPointer,
            attentionRegionInScreenSpace: pointerContext.attentionRegionInScreenSpace
        )
    }
}
