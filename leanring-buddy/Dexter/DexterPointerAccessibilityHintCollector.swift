//
//  DexterPointerAccessibilityHintCollector.swift
//  leanring-buddy
//

import AppKit
import ApplicationServices
import Foundation

/// Reads accessibility attributes near the pointer. Hints only — not semantic UI identification.
enum DexterPointerAccessibilityHintCollector {
    static func collectHint(
        hasAccessibilityPermission: Bool,
        pointerLocationInScreenSpace: CGPoint
    ) -> DexterAccessibilityHintAtPointer {
        guard hasAccessibilityPermission else {
            return DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .permissionMissing
            )
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var elementAtPointer: AXUIElement?
        let elementAtPointerResult = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(pointerLocationInScreenSpace.x),
            Float(pointerLocationInScreenSpace.y),
            &elementAtPointer
        )

        guard elementAtPointerResult == .success, let elementAtPointer else {
            return DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            )
        }

        let roleDescription = copyAttributeString(elementAtPointer, attribute: kAXRoleDescriptionAttribute as CFString)
        let title = copyAttributeString(elementAtPointer, attribute: kAXTitleAttribute as CFString)
            ?? copyAttributeString(elementAtPointer, attribute: kAXDescriptionAttribute as CFString)
        let valueDescription = copyAttributeValueDescription(elementAtPointer)

        if roleDescription == nil && title == nil && valueDescription == nil {
            return DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            )
        }

        return DexterAccessibilityHintAtPointer(
            roleDescription: roleDescription,
            title: title,
            valueDescription: valueDescription,
            availability: .available
        )
    }

    private static func copyAttributeValueDescription(_ element: AXUIElement) -> String? {
        var attributeValue: AnyObject?
        let copyResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &attributeValue)
        guard copyResult == .success, let attributeValue else { return nil }

        if let numberValue = attributeValue as? NSNumber {
            return numberValue.stringValue
        }
        if let stringValue = attributeValue as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return String(describing: attributeValue)
    }

    private static func copyAttributeString(_ element: AXUIElement, attribute: CFString) -> String? {
        var attributeValue: AnyObject?
        let copyResult = AXUIElementCopyAttributeValue(element, attribute, &attributeValue)
        guard copyResult == .success else { return nil }

        let stringValue = (attributeValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stringValue, !stringValue.isEmpty else { return nil }
        return stringValue
    }
}
