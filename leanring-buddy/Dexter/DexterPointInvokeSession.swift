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

    var activeApplicationDisplayName: String? {
        contextSnapshot.activeApplicationName
    }

    var activeWindowTitle: String? {
        contextSnapshot.activeWindowTitle
    }

    var contextualIndicatorLabel: String {
        if let applicationName = activeApplicationDisplayName, !applicationName.isEmpty {
            return "Looking at \(applicationName)"
        }
        return "Screen context captured"
    }
}
