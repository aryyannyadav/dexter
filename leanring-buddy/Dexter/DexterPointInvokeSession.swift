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
}
