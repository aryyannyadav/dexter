//
//  DexterContextSnapshot.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

/// Point-in-time context actually collected for a Dexter turn (not persisted).
struct DexterContextSnapshot: Equatable {
    let capturedAt: Date
    let permissionState: DexterContextPermissionState

    let primaryScreenshotJPEG: Data?
    let screenshotLabel: String?

    let activeApplicationName: String?
    let activeWindowTitle: String?

    let pointerLocationInScreenSpace: CGPoint?

    let selectedText: String?

    let browserURL: String?
    let browserPageTitle: String?

    let screenCaptureAvailability: DexterContextAvailability
    let userRequestedScreenContext: Bool
}

struct DexterContextPermissionState: Equatable {
    let hasScreenRecordingPermission: Bool
    let hasAccessibilityPermission: Bool
    let hasScreenContentPermission: Bool
}

enum DexterContextSnapshotBuilder {
    static func make(
        from dexterContext: DexterContext,
        permissionState: DexterContextPermissionState,
        userRequestedScreenContext: Bool,
        capturedAt: Date = Date()
    ) -> DexterContextSnapshot {
        let primaryScreenshot = dexterContext.screen.primaryScreenshot

        return DexterContextSnapshot(
            capturedAt: capturedAt,
            permissionState: permissionState,
            primaryScreenshotJPEG: primaryScreenshot?.imageData,
            screenshotLabel: primaryScreenshot?.label,
            activeApplicationName: dexterContext.activeApplication.localizedName,
            activeWindowTitle: dexterContext.activeWindow.title,
            pointerLocationInScreenSpace: dexterContext.pointerLocationInScreenSpace,
            selectedText: dexterContext.selectedText.selectedText,
            browserURL: nil,
            browserPageTitle: nil,
            screenCaptureAvailability: dexterContext.screen.captureAvailability,
            userRequestedScreenContext: userRequestedScreenContext
        )
    }
}

enum DexterContextHonestyInstructions {
    static func supplementalSystemInstructions(
        userRequestedScreenContext: Bool,
        screenCaptureAvailability: DexterContextAvailability,
        hasAttachedScreenshot: Bool
    ) -> String {
        guard userRequestedScreenContext else { return "" }

        if hasAttachedScreenshot {
            return """
            A screenshot from the user's display is attached to this request. Describe only what you can justify from the image and the text context sections. If something is not visible, say so.
            """
        }

        switch screenCaptureAvailability {
        case .permissionMissing:
            return """
            The user asked about what is on screen, but Dexter does not have Screen Recording permission, so no screenshot was captured. Clearly tell the user that screen recording permission is required before you can see their screen. Do not guess or invent screen contents.
            """
        case .unavailable(let errorDescription):
            return """
            The user asked about what is on screen, but screenshot capture failed (\(errorDescription)). Tell the user you could not access the screen right now. Do not guess or invent screen contents.
            """
        case .notApplicable:
            return """
            The user asked about what is on screen, but no screenshot was captured for this turn. Tell the user you cannot see their screen right now. Do not guess or invent screen contents.
            """
        case .available:
            return ""
        }
    }
}
