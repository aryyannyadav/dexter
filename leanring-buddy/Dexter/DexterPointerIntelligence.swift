//
//  DexterPointerIntelligence.swift
//  leanring-buddy
//
//  Pointer → semantic target models (Accessibility, app metadata, OCR, local vision).
//

import CoreGraphics
import Foundation

enum DexterPointerEvidenceSource: String, Equatable, CaseIterable {
    case accessibility = "accessibility"
    case applicationMetadata = "applicationMetadata"
    case ocr = "ocr"
    case vision = "vision"
}

struct DexterPointerEvidenceContribution: Equatable {
    let source: DexterPointerEvidenceSource
    let detail: String
    let weight: Double
}

/// Resolved UI target at the pointer for explanation and action planning.
struct DexterPointerSemanticTarget: Equatable {
    let primaryLabel: String
    let roleDescription: String?
    let valueDescription: String?
    let applicationContextLabel: String?
    let windowContextLabel: String?
    let ocrTextNearPointer: String?
    let visionAppearanceHint: String?
    let evidence: [DexterPointerEvidenceContribution]
    let confidence: Double

    var confirmationLabel: String {
        let trimmedPrimary = primaryLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrimary.isEmpty, trimmedPrimary != "UI element at pointer" {
            return trimmedPrimary
        }
        if let roleDescription, !roleDescription.isEmpty {
            return roleDescription
        }
        return "the control under your pointer"
    }

    var modelSummaryLine: String {
        var parts: [String] = ["semantic target: \(primaryLabel) (confidence \(String(format: "%.2f", confidence)))"]
        if let roleDescription, !roleDescription.isEmpty {
            parts.append("role: \(roleDescription)")
        }
        if let valueDescription, !valueDescription.isEmpty {
            parts.append("value: \(valueDescription)")
        }
        if let ocrTextNearPointer, !ocrTextNearPointer.isEmpty {
            parts.append("nearby text (OCR): \(ocrTextNearPointer)")
        }
        if let visionAppearanceHint, !visionAppearanceHint.isEmpty {
            parts.append("appearance (local vision): \(visionAppearanceHint)")
        }
        if let applicationContextLabel, !applicationContextLabel.isEmpty {
            parts.append("application: \(applicationContextLabel)")
        }
        if let windowContextLabel, !windowContextLabel.isEmpty {
            parts.append("window: \(windowContextLabel)")
        }
        return parts.joined(separator: "; ")
    }
}

struct DexterPointerOCRAnalysisResult: Equatable {
    let textAtPointer: String?
    let nearbyText: String?
    let availability: DexterContextAvailability
}

struct DexterPointerVisionAnalysisResult: Equatable {
    let appearanceDescription: String?
    let isPredominantlyRed: Bool
    let availability: DexterContextAvailability
}

struct DexterPointerIntelligencePipelineInput: Equatable {
    let pointerLocationInScreenSpace: CGPoint
    let capturedAt: Date
    let display: DexterDisplayContext?
    let activeApplication: DexterActiveApplicationContext?
    let activeWindow: DexterActiveWindowContext?
    let attentionContext: DexterAttentionContext
    let accessibilityHintAtPointer: DexterAccessibilityHintAtPointer
    /// On-demand ScreenCaptureKit snapshot for this turn only (never continuous recording).
    let primaryScreenshot: DexterScreenCaptureSnapshot?
    /// When `ElementLocationDetector` finds an element near the pointer (optional per turn).
    let elementLocationCorroboratesPointer: Bool
    let userMessage: String?

    init(
        pointerLocationInScreenSpace: CGPoint,
        capturedAt: Date,
        display: DexterDisplayContext?,
        activeApplication: DexterActiveApplicationContext?,
        activeWindow: DexterActiveWindowContext?,
        attentionContext: DexterAttentionContext,
        accessibilityHintAtPointer: DexterAccessibilityHintAtPointer,
        primaryScreenshot: DexterScreenCaptureSnapshot?,
        elementLocationCorroboratesPointer: Bool = false,
        userMessage: String? = nil
    ) {
        self.pointerLocationInScreenSpace = pointerLocationInScreenSpace
        self.capturedAt = capturedAt
        self.display = display
        self.activeApplication = activeApplication
        self.activeWindow = activeWindow
        self.attentionContext = attentionContext
        self.accessibilityHintAtPointer = accessibilityHintAtPointer
        self.primaryScreenshot = primaryScreenshot
        self.elementLocationCorroboratesPointer = elementLocationCorroboratesPointer
        self.userMessage = userMessage
    }
}
