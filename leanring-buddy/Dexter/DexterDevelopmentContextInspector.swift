//
//  DexterDevelopmentContextInspector.swift
//  leanring-buddy
//

import Foundation

enum DexterDevelopmentContextInspectorSettings {
    private static let userDefaultsKey = "dexterDevelopmentContextInspectorEnabled"

    static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
        #else
        return false
        #endif
    }

    static func setEnabled(_ isEnabled: Bool) {
        #if DEBUG
        UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
        #endif
    }
}

struct DexterDevelopmentContextInspectorSnapshot: Equatable {
    let pointerCoordinatesDescription: String
    let activeApplicationDescription: String
    let activeWindowDescription: String
    let displayDescription: String
    let screenshotStatusDescription: String
    let capturedAt: Date

    init(context: DexterContext, capturedAt: Date = Date()) {
        let attention = context.attention
        pointerCoordinatesDescription = String(
            format: "screen (%.0f, %.0f)",
            attention.pointerLocationInScreenSpace.x,
            attention.pointerLocationInScreenSpace.y
        )

        switch context.activeApplication.availability {
        case .available:
            activeApplicationDescription = context.activeApplication.localizedName
                ?? context.activeApplication.bundleIdentifier
                ?? "unknown"
        case .permissionMissing:
            activeApplicationDescription = "unavailable (accessibility permission missing)"
        case .notApplicable:
            activeApplicationDescription = "not collected"
        case .unavailable(let errorDescription):
            activeApplicationDescription = "unavailable (\(errorDescription))"
        }

        switch context.activeWindow.availability {
        case .available:
            activeWindowDescription = context.activeWindow.title ?? "untitled window"
        case .permissionMissing:
            activeWindowDescription = "unavailable (accessibility permission missing)"
        case .notApplicable:
            activeWindowDescription = "not collected"
        case .unavailable(let errorDescription):
            activeWindowDescription = "unavailable (\(errorDescription))"
        }

        if let displayIdentifier = attention.primaryDisplayIdentifier {
            displayDescription = "display \(displayIdentifier)"
        } else if let display = context.display {
            displayDescription = "display \(display.displayIdentifier)"
        } else {
            displayDescription = "unknown display"
        }

        screenshotStatusDescription = Self.screenshotStatusDescription(for: context.screen)
        self.capturedAt = capturedAt
    }

    private static func screenshotStatusDescription(for screenContext: DexterScreenContext) -> String {
        switch screenContext.captureAvailability {
        case .available:
            let screenCount = screenContext.allScreens.count
            let includesPrimary = screenContext.primaryScreenshot != nil
            if screenCount == 0 {
                return "no images"
            }
            return includesPrimary
                ? "captured \(screenCount) screen(s), pointer display included"
                : "captured \(screenCount) screen(s)"
        case .permissionMissing:
            return "not captured (screen recording permission missing)"
        case .notApplicable:
            return "skipped"
        case .unavailable(let errorDescription):
            return "failed (\(errorDescription))"
        }
    }
}
