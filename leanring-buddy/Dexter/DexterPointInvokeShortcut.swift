//
//  DexterPointInvokeShortcut.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

/// Global shortcut to capture context at the pointer and open Dexter (distinct from push-to-talk).
enum DexterPointInvokeShortcut {
    static let displayText = "ctrl + option + D"
    static let invokeKeyCode: UInt16 = 2

    static func shouldTriggerPointInvoke(
        for eventType: CGEventType,
        keyCode: UInt16,
        modifierFlagsRawValue: UInt64
    ) -> Bool {
        guard eventType == .keyDown else { return false }
        guard keyCode == invokeKeyCode else { return false }

        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(modifierFlagsRawValue))
            .intersection(.deviceIndependentFlagsMask)
        return modifierFlags.contains(.control) && modifierFlags.contains(.option)
    }
}
