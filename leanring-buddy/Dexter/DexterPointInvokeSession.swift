//
//  DexterPointInvokeSession.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

/// Frozen pointer context captured when the user invokes Dexter at the cursor (in-memory only).
struct DexterPointInvokeSession: Equatable {
    let pointerLocationInScreenSpace: CGPoint
    let capturedAt: Date
    let contextSnapshot: DexterContextSnapshot
    let screenCaptureSnapshots: [DexterScreenCaptureSnapshot]
    /// Present only when pointer intelligence resolved a target with enough confidence.
    let pointerSemanticTarget: DexterPointerSemanticTarget?

    var activeApplicationDisplayName: String? {
        contextSnapshot.activeApplicationName
    }

    var activeWindowTitle: String? {
        contextSnapshot.activeWindowTitle
    }

    var contextualIndicatorLabel: String {
        if let userFacingTargetLabel = userFacingSemanticTargetLabel {
            return userFacingTargetLabel
        }
        if let applicationName = activeApplicationDisplayName, !applicationName.isEmpty {
            return "Looking at \(applicationName)"
        }
        return "Screen context captured"
    }

    var userFacingSemanticTargetLabel: String? {
        guard let pointerSemanticTarget else { return nil }
        guard pointerSemanticTarget.confidence >= 0.28 else { return nil }
        let trimmedPrimaryLabel = pointerSemanticTarget.primaryLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrimaryLabel.isEmpty, trimmedPrimaryLabel != "UI element at pointer" else {
            return nil
        }
        return pointerSemanticTarget.confirmationLabel
    }

    /// Hub secondary line: resolved target plus app/window when safe (no invented labels).
    var hubTargetPresentationSubtitle: String? {
        if let userFacingTargetLabel = userFacingSemanticTargetLabel {
            if let applicationName = activeApplicationDisplayName?.nonEmptyTrimmedValue {
                return "\(userFacingTargetLabel) · \(applicationName)"
            }
            return userFacingTargetLabel
        }
        if let windowTitle = activeWindowTitle?.nonEmptyTrimmedValue,
           let applicationName = activeApplicationDisplayName?.nonEmptyTrimmedValue {
            return "\(applicationName) — \(windowTitle)"
        }
        return activeApplicationDisplayName?.nonEmptyTrimmedValue
    }

    static let hubLowConfidenceThreshold = 0.45

    var requiresHubTargetConfirmationBeat: Bool {
        guard let pointerSemanticTarget else { return true }
        if pointerSemanticTarget.confidence < Self.hubLowConfidenceThreshold {
            return true
        }
        return userFacingSemanticTargetLabel == nil
    }

    /// Label for low-confidence Hub copy; nil when there is nothing honest to show.
    var hubUncertainTargetPromptLabel: String? {
        guard requiresHubTargetConfirmationBeat else { return nil }
        if let userFacingTargetLabel = userFacingSemanticTargetLabel {
            return userFacingTargetLabel
        }
        guard let pointerSemanticTarget else { return nil }
        let confirmationLabel = pointerSemanticTarget.confirmationLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !confirmationLabel.isEmpty, confirmationLabel != "the control under your pointer" else {
            return nil
        }
        return confirmationLabel
    }

    /// Highest-weight evidence source for diagnostics (accessibility → app metadata → OCR → vision).
    var primaryResolutionSourceForDiagnostics: String {
        guard let pointerSemanticTarget else { return "none" }
        guard let strongestEvidence = pointerSemanticTarget.evidence.max(by: { $0.weight < $1.weight }) else {
            return "none"
        }
        return strongestEvidence.source.rawValue
    }
}
