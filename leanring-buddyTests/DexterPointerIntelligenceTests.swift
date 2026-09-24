//
//  DexterPointerIntelligenceTests.swift
//  leanring-buddyTests
//

import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import leanring_buddy

struct StubPointerRegionOCRAnalyzer: DexterPointerRegionOCRAnalyzing {
    let result: DexterPointerOCRAnalysisResult

    func analyze(
        screenshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> DexterPointerOCRAnalysisResult {
        result
    }
}

struct StubPointerRegionVisionAnalyzer: DexterPointerRegionVisionAnalyzing {
    let result: DexterPointerVisionAnalysisResult

    func analyze(
        screenshot: DexterScreenCaptureSnapshot,
        attentionContext: DexterAttentionContext
    ) -> DexterPointerVisionAnalysisResult {
        result
    }
}

struct DexterPointerIntelligenceTests {
    private static let pointerLocation = CGPoint(x: 640, y: 400)
    private static let displayFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    private static func attentionContext(accessibilityHint: DexterAccessibilityHintAtPointer) -> DexterAttentionContext {
        DexterPointerAttentionCalculator.buildAttentionContext(
            pointerLocationInScreenSpace: pointerLocation,
            display: DexterDisplayContext(displayIdentifier: 1, displayFrameInScreenSpace: displayFrame),
            primaryScreenshot: nil,
            accessibilityHintAtPointer: accessibilityHint
        )
    }

    @Test func semanticTargetPrefersAccessibilityOverOCR() {
        let target = DexterPointerSemanticTargetResolver.resolve(
            accessibilityHint: DexterAccessibilityHintAtPointer(
                roleDescription: "button",
                title: "Submit",
                valueDescription: nil,
                availability: .available
            ),
            activeApplication: DexterActiveApplicationContext(
                bundleIdentifier: "com.example.app",
                localizedName: "Example",
                availability: .available
            ),
            activeWindow: DexterActiveWindowContext(title: "Form", availability: .available),
            ocrResult: DexterPointerOCRAnalysisResult(
                textAtPointer: "Cancel",
                nearbyText: nil,
                availability: .available
            ),
            visionResult: DexterPointerVisionAnalysisResult(
                appearanceDescription: nil,
                isPredominantlyRed: false,
                availability: .notApplicable
            )
        )

        #expect(target.primaryLabel == "Submit")
        #expect(target.confidence > 0.5)
        #expect(target.confirmationLabel == "Submit")
    }

    @Test func semanticTargetUsesOCRWhenAccessibilityMissing() {
        let target = DexterPointerSemanticTargetResolver.resolve(
            accessibilityHint: DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            ),
            activeApplication: nil,
            activeWindow: nil,
            ocrResult: DexterPointerOCRAnalysisResult(
                textAtPointer: "Settings",
                nearbyText: nil,
                availability: .available
            ),
            visionResult: DexterPointerVisionAnalysisResult(
                appearanceDescription: nil,
                isPredominantlyRed: false,
                availability: .notApplicable
            )
        )

        #expect(target.primaryLabel == "Settings")
        #expect(target.ocrTextNearPointer == "Settings")
    }

    @Test func pipelineBuildsPointerContextWithoutScreenshot() {
        let input = DexterPointerIntelligencePipelineInput(
            pointerLocationInScreenSpace: pointerLocation,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            display: DexterDisplayContext(displayIdentifier: 42, displayFrameInScreenSpace: displayFrame),
            activeApplication: DexterActiveApplicationContext(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari",
                availability: .available
            ),
            activeWindow: DexterActiveWindowContext(title: "Apple", availability: .available),
            attentionContext: attentionContext(
                accessibilityHint: DexterAccessibilityHintAtPointer(
                    roleDescription: "link",
                    title: "Learn more",
                    valueDescription: nil,
                    availability: .available
                )
            ),
            accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                roleDescription: "link",
                title: "Learn more",
                valueDescription: nil,
                availability: .available
            ),
            primaryScreenshot: nil
        )

        let pointerContext = DexterPointerIntelligencePipeline.buildPointerContext(
            input: input,
            ocrAnalyzer: StubPointerRegionOCRAnalyzer(
                result: DexterPointerOCRAnalysisResult(textAtPointer: nil, nearbyText: nil, availability: .notApplicable)
            ),
            visionAnalyzer: StubPointerRegionVisionAnalyzer(
                result: DexterPointerVisionAnalysisResult(
                    appearanceDescription: nil,
                    isPredominantlyRed: false,
                    availability: .notApplicable
                )
            )
        )

        #expect(pointerContext.x == pointerLocation.x)
        #expect(pointerContext.y == pointerLocation.y)
        #expect(pointerContext.screenDisplayIdentifier == 42)
        #expect(pointerContext.semanticTarget?.primaryLabel == "Learn more")
        #expect(pointerContext.attentionRegionInScreenSpace != nil)
    }

    @Test func pipelineMergesVisionHintForRedAppearance() {
        let input = DexterPointerIntelligencePipelineInput(
            pointerLocationInScreenSpace: pointerLocation,
            capturedAt: Date(),
            display: nil,
            activeApplication: nil,
            activeWindow: nil,
            attentionContext: attentionContext(
                accessibilityHint: DexterAccessibilityHintAtPointer(
                    roleDescription: nil,
                    title: nil,
                    valueDescription: nil,
                    availability: .notApplicable
                )
            ),
            accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            ),
            primaryScreenshot: DexterScreenCaptureSnapshot(
                imageData: Data(),
                label: "primary",
                isCursorScreen: true,
                displayWidthInPoints: 1440,
                displayHeightInPoints: 900,
                displayFrame: displayFrame,
                screenshotWidthInPixels: 2880,
                screenshotHeightInPixels: 1800
            )
        )

        let pointerContext = DexterPointerIntelligencePipeline.buildPointerContext(
            input: input,
            ocrAnalyzer: StubPointerRegionOCRAnalyzer(
                result: DexterPointerOCRAnalysisResult(textAtPointer: nil, nearbyText: nil, availability: .notApplicable)
            ),
            visionAnalyzer: StubPointerRegionVisionAnalyzer(
                result: DexterPointerVisionAnalysisResult(
                    appearanceDescription: "red-toned at pointer",
                    isPredominantlyRed: true,
                    availability: .available
                )
            )
        )

        #expect(pointerContext.semanticTarget?.visionAppearanceHint == "red-toned at pointer")
        #expect(pointerContext.semanticTarget?.primaryLabel == "red-toned at pointer")
    }

    @Test func structuredPromptIncludesSemanticTargetSummary() {
        let semanticTarget = DexterPointerSemanticTarget(
            primaryLabel: "Enable Notifications",
            roleDescription: "checkbox",
            valueDescription: "off",
            applicationContextLabel: "System Settings",
            windowContextLabel: "Notifications",
            ocrTextNearPointer: nil,
            visionAppearanceHint: nil,
            evidence: [
                DexterPointerEvidenceContribution(source: .accessibility, detail: "title: Enable Notifications", weight: 0.42)
            ],
            confidence: 0.72
        )

        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "What is this?"),
            pointer: DexterPointerContext(
                screenDisplayIdentifier: 1,
                locationInScreenSpace: pointerLocation,
                semanticTarget: semanticTarget,
                confidence: 0.72,
                attentionRegionInScreenSpace: CGRect(x: 480, y: 240, width: 320, height: 320)
            ),
            attention: attentionContext(
                accessibilityHint: DexterAccessibilityHintAtPointer(
                    roleDescription: "checkbox",
                    title: "Enable Notifications",
                    valueDescription: "off",
                    availability: .available
                )
            )
        )

        let plan = DexterContextRelevancePlan(
            includeActiveApplication: false,
            includeActiveWindow: true,
            includePointerContext: true,
            includeScreenContext: false,
            includeSelectedText: false,
            includeRecentConversationInPrompt: false,
            includeRecentConversationInAPIHistory: false,
            includeCurrentTask: false,
            includePersistentMemory: false,
            includePersonalContextGraph: false
        )

        let structured = DexterStructuredModelRequestBuilder.build(dexterContext: context, relevancePlan: plan)
        #expect(structured.userPrompt.contains("POINTER CONTEXT"))
        #expect(structured.userPrompt.contains("Enable Notifications"))
        #expect(structured.userPrompt.contains("confidence"))
    }

    @Test func colorDescriptionDetectsPredominantlyRed() {
        let redColor = NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        #expect(DexterPointerColorDescription.isPredominantlyRed(redColor))
        #expect(DexterPointerColorDescription.describe(redColor) == "red-toned at pointer")
    }

    @Test func elementLocationCorroborationDetectsNearbyDetection() {
        let corroborates = DexterPointerElementLocationCorroboration.corroboratesPointer(
            detectedLocationInDisplayPoints: CGPoint(x: 642, y: 402),
            pointerLocationInScreenSpace: pointerLocation,
            displayFrameInScreenSpace: displayFrame
        )
        #expect(corroborates)
    }
}
