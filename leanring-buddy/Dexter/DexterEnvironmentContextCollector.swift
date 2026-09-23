//
//  DexterEnvironmentContextCollector.swift
//  leanring-buddy
//

import AppKit
import ApplicationServices
import Foundation

struct DexterEnvironmentCollectionResult: Equatable {
    let activeApplication: DexterActiveApplicationContext
    let activeWindow: DexterActiveWindowContext
    let selectedText: DexterSelectedTextContext
    let display: DexterDisplayContext?
}

/// Collects frontmost app, window title, and selection via Accessibility (no screen capture).
enum DexterEnvironmentContextCollector {
    static func collect(
        hasAccessibilityPermission: Bool,
        pointerLocationInScreenSpace: CGPoint
    ) -> DexterEnvironmentCollectionResult {
        let displayContext = displayContext(forPointerLocation: pointerLocationInScreenSpace)

        guard hasAccessibilityPermission else {
            return DexterEnvironmentCollectionResult(
                activeApplication: DexterActiveApplicationContext(
                    bundleIdentifier: nil,
                    localizedName: nil,
                    availability: .permissionMissing
                ),
                activeWindow: DexterActiveWindowContext(title: nil, availability: .permissionMissing),
                selectedText: DexterSelectedTextContext(selectedText: nil, availability: .permissionMissing),
                display: displayContext
            )
        }

        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return DexterEnvironmentCollectionResult(
                activeApplication: DexterActiveApplicationContext(
                    bundleIdentifier: nil,
                    localizedName: nil,
                    availability: .unavailable(errorDescription: "No frontmost application")
                ),
                activeWindow: DexterActiveWindowContext(title: nil, availability: .unavailable(errorDescription: "No frontmost application")),
                selectedText: DexterSelectedTextContext(selectedText: nil, availability: .unavailable(errorDescription: "No frontmost application")),
                display: displayContext
            )
        }

        let activeApplication = DexterActiveApplicationContext(
            bundleIdentifier: frontmostApplication.bundleIdentifier,
            localizedName: frontmostApplication.localizedName,
            availability: .available
        )

        let applicationElement = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
        var focusedWindowValue: AnyObject?
        let focusedWindowResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )

        guard focusedWindowResult == .success, let focusedWindowValue else {
            return DexterEnvironmentCollectionResult(
                activeApplication: activeApplication,
                activeWindow: DexterActiveWindowContext(title: nil, availability: .unavailable(errorDescription: "Focused window unavailable")),
                selectedText: DexterSelectedTextContext(selectedText: nil, availability: .unavailable(errorDescription: "Focused window unavailable")),
                display: displayContext
            )
        }

        let focusedWindowElement = focusedWindowValue as! AXUIElement

        var windowTitleValue: AnyObject?
        let windowTitleResult = AXUIElementCopyAttributeValue(
            focusedWindowElement,
            kAXTitleAttribute as CFString,
            &windowTitleValue
        )
        let windowTitle = (windowTitleResult == .success ? windowTitleValue as? String : nil)

        let activeWindow = DexterActiveWindowContext(
            title: windowTitle,
            availability: windowTitleResult == .success ? .available : .unavailable(errorDescription: "Window title unavailable")
        )

        let selectedText = readSelectedText(fromFocusedWindow: focusedWindowElement)

        return DexterEnvironmentCollectionResult(
            activeApplication: activeApplication,
            activeWindow: activeWindow,
            selectedText: selectedText,
            display: displayContext
        )
    }

    private static func displayContext(forPointerLocation pointerLocation: CGPoint) -> DexterDisplayContext? {
        guard let screenContainingPointer = NSScreen.screens.first(where: { $0.frame.contains(pointerLocation) }) else {
            return nil
        }

        return DexterDisplayContext(
            displayIdentifier: screenContainingPointer.displayID,
            displayFrameInScreenSpace: screenContainingPointer.frame
        )
    }

    private static func readSelectedText(fromFocusedWindow focusedWindowElement: AXUIElement) -> DexterSelectedTextContext {
        var focusedElementValue: AnyObject?
        let focusedElementResult = AXUIElementCopyAttributeValue(
            focusedWindowElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        )

        guard focusedElementResult == .success, let focusedElementValue else {
            return DexterSelectedTextContext(selectedText: nil, availability: .notApplicable)
        }

        let focusedElement = focusedElementValue as! AXUIElement
        var selectedTextValue: AnyObject?
        let selectedTextResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        guard selectedTextResult == .success else {
            return DexterSelectedTextContext(selectedText: nil, availability: .notApplicable)
        }

        let selectedText = (selectedTextValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedText, !selectedText.isEmpty {
            return DexterSelectedTextContext(selectedText: selectedText, availability: .available)
        }

        return DexterSelectedTextContext(selectedText: nil, availability: .notApplicable)
    }
}
