//
//  DexterApplicationLifecycleIntentParserTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterApplicationLifecycleIntentParserTests {
    @Test func recognizesLaunchIntent() {
        let intent = DexterApplicationLifecycleIntentParser.parse(from: "open calculator")
        #expect(intent?.operation == .launch)
        #expect(intent?.applicationName == "Calculator")
    }

    @Test func recognizesQuitIntent() {
        let intent = DexterApplicationLifecycleIntentParser.parse(from: "quit calculator")
        #expect(intent?.operation == .quit)
        #expect(intent?.applicationName == "Calculator")
    }

    @Test func recognizesFocusIntent() {
        let intent = DexterApplicationLifecycleIntentParser.parse(from: "focus calculator")
        #expect(intent?.operation == .focus)
        #expect(intent?.applicationName == "Calculator")
    }

    @Test func recognizesCloseAsQuit() {
        let intent = DexterApplicationLifecycleIntentParser.parse(from: "close calculator")
        #expect(intent?.operation == .quit)
    }
}
