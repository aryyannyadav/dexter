//
//  DexterPointInvokeShortcutTests.swift
//  leanring-buddyTests
//

import CoreGraphics
import Testing
@testable import Dexter

struct DexterPointInvokeShortcutTests {
    @Test func pointInvokeShortcutRequiresControlOptionDKeyDown() {
        let controlOptionFlags = NSEvent.ModifierFlags([.control, .option]).rawValue

        #expect(
            DexterPointInvokeShortcut.shouldTriggerPointInvoke(
                for: .keyDown,
                keyCode: DexterPointInvokeShortcut.invokeKeyCode,
                modifierFlagsRawValue: UInt64(controlOptionFlags)
            )
        )

        #expect(
            !DexterPointInvokeShortcut.shouldTriggerPointInvoke(
                for: .keyUp,
                keyCode: DexterPointInvokeShortcut.invokeKeyCode,
                modifierFlagsRawValue: UInt64(controlOptionFlags)
            )
        )
    }
}
