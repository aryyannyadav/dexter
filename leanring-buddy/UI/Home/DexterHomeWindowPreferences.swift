//
//  DexterHomeWindowPreferences.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

enum DexterHomeWindowLayoutMode: String, Codable, CaseIterable {
    case compact
    case normal
    case expanded

    var defaultContentSize: NSSize {
        switch self {
        case .compact:
            return NSSize(width: 760, height: 520)
        case .normal:
            return NSSize(width: 980, height: 660)
        case .expanded:
            return NSSize(width: 1180, height: 780)
        }
    }

    var minimumSize: NSSize {
        switch self {
        case .compact:
            return NSSize(width: 680, height: 480)
        case .normal:
            return NSSize(width: 760, height: 520)
        case .expanded:
            return NSSize(width: 900, height: 600)
        }
    }
}

enum DexterHomeWindowPreferences {
    private static let layoutModeKey = "dexterHomeWindowLayoutMode"
    private static let frameOriginXKey = "dexterHomeWindowFrameOriginX"
    private static let frameOriginYKey = "dexterHomeWindowFrameOriginY"
    private static let frameWidthKey = "dexterHomeWindowFrameWidth"
    private static let frameHeightKey = "dexterHomeWindowFrameHeight"

    static var layoutMode: DexterHomeWindowLayoutMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: layoutModeKey),
                  let mode = DexterHomeWindowLayoutMode(rawValue: raw) else {
                return .normal
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: layoutModeKey)
        }
    }

    static func savedFrame() -> CGRect? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: frameWidthKey) != nil else { return nil }
        return CGRect(
            x: defaults.double(forKey: frameOriginXKey),
            y: defaults.double(forKey: frameOriginYKey),
            width: defaults.double(forKey: frameWidthKey),
            height: defaults.double(forKey: frameHeightKey)
        )
    }

    static func saveFrame(_ frame: CGRect) {
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: frameOriginXKey)
        defaults.set(frame.origin.y, forKey: frameOriginYKey)
        defaults.set(frame.width, forKey: frameWidthKey)
        defaults.set(frame.height, forKey: frameHeightKey)
    }

    static func applyLayoutMode(_ mode: DexterHomeWindowLayoutMode, to window: NSWindow) {
        layoutMode = mode
        window.minSize = mode.minimumSize
        window.setContentSize(mode.defaultContentSize)
        window.center()
    }
}

/// Persists main window frame when the user moves or resizes.
@MainActor
final class DexterHomeWindowFrameObserver: NSObject, NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        persistFrame(from: notification)
    }

    func windowDidResize(_ notification: Notification) {
        persistFrame(from: notification)
    }

    private func persistFrame(from notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        DexterHomeWindowPreferences.saveFrame(window.frame)
    }
}
