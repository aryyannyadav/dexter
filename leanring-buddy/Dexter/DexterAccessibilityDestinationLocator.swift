//
//  DexterAccessibilityDestinationLocator.swift
//  leanring-buddy
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum DexterAccessibilityDestinationLocator {
    private static let maxSearchDepth = 12

    @MainActor
    static func locateCenterInScreenSpace(
        destinationLabel: String,
        expectedApplicationName: String?,
        hasAccessibilityPermission: Bool
    ) -> CGPoint? {
        guard hasAccessibilityPermission else { return nil }

        let normalizedDestination = destinationLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedDestination.isEmpty else { return nil }

        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if let expectedApplicationName,
           let frontmostName = frontmostApplication?.localizedName,
           let canonicalExpected = DexterApplicationNameFormatter.canonicalApplicationName(from: expectedApplicationName),
           let canonicalFrontmost = DexterApplicationNameFormatter.canonicalApplicationName(from: frontmostName),
           canonicalExpected.caseInsensitiveCompare(canonicalFrontmost) != .orderedSame {
            if let resolvedApplication = NSWorkspace.shared.runningApplications.first(where: { runningApplication in
                guard let localizedName = runningApplication.localizedName else { return false }
                guard let canonicalRunning = DexterApplicationNameFormatter.canonicalApplicationName(from: localizedName) else {
                    return false
                }
                return canonicalRunning.caseInsensitiveCompare(canonicalExpected) == .orderedSame
            }) {
                return locateInProcess(
                    processIdentifier: resolvedApplication.processIdentifier,
                    normalizedDestination: normalizedDestination
                )
            }
        }

        guard let processIdentifier = frontmostApplication?.processIdentifier else { return nil }
        return locateInProcess(processIdentifier: processIdentifier, normalizedDestination: normalizedDestination)
    }

    @MainActor
    private static func locateInProcess(
        processIdentifier: pid_t,
        normalizedDestination: String
    ) -> CGPoint? {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        return search(element: applicationElement, normalizedDestination: normalizedDestination, depth: 0)
    }

    @MainActor
    private static func search(
        element: AXUIElement,
        normalizedDestination: String,
        depth: Int
    ) -> CGPoint? {
        guard depth <= maxSearchDepth else { return nil }

        if elementMatches(element: element, normalizedDestination: normalizedDestination),
           let center = centerInScreenSpace(for: element) {
            return center
        }

        guard let children = childElements(of: element) else { return nil }
        for child in children {
            if let center = search(element: child, normalizedDestination: normalizedDestination, depth: depth + 1) {
                return center
            }
        }
        return nil
    }

    private static func elementMatches(element: AXUIElement, normalizedDestination: String) -> Bool {
        let candidates = [
            copyAttributeString(element, attribute: kAXTitleAttribute as CFString),
            copyAttributeString(element, attribute: kAXDescriptionAttribute as CFString),
            copyAttributeString(element, attribute: kAXRoleDescriptionAttribute as CFString),
            copyAttributeString(element, attribute: kAXValueAttribute as CFString)
        ]
        for candidate in candidates.compactMap({ $0?.lowercased() }) {
            if candidate == normalizedDestination || candidate.contains(normalizedDestination) {
                return true
            }
        }
        return false
    }

    private static func centerInScreenSpace(for element: AXUIElement) -> CGPoint? {
        guard let frame = frameInScreenSpace(for: element) else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private static func frameInScreenSpace(for element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionRef = positionValue,
              let sizeRef = sizeValue else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private static func childElements(of element: AXUIElement) -> [AXUIElement]? {
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let childrenArray = childrenValue as? [AXUIElement] else {
            return nil
        }
        return childrenArray
    }

    private static func copyAttributeString(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        if let string = value as? String { return string }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }
}
