//
//  DexterComputerInteractionIntentParserTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterComputerInteractionIntentParserTests {
    @Test func parsesScrollDown() {
        let intent = DexterComputerInteractionIntentParser.parse(from: "scroll down")
        #expect(intent == .scroll(direction: "down", amount: nil))
    }

    @Test func parsesTypeText() {
        let intent = DexterComputerInteractionIntentParser.parse(from: "type hello")
        #expect(intent == .typeText("hello"))
    }

    @Test func parsesKeyboardShortcut() {
        let intent = DexterComputerInteractionIntentParser.parse(from: "press command shift p")
        #expect(intent == .keyboardShortcut("command shift p"))
    }

    @Test func parsesRightClickPointerIntent() {
        let intent = DexterComputerInteractionIntentParser.parse(from: "right click it")
        #expect(intent == .clickPointer(button: "right"))
    }
}
