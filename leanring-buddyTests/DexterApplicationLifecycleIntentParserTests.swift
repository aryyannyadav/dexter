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

    @Test func launchIntentStopsApplicationNameAtConjunction() {
        let intent = DexterApplicationLifecycleIntentParser.parse(from: "open telegram and open settings there")
        #expect(intent?.operation == .launch)
        #expect(intent?.applicationName == "Telegram")
    }

    @Test func extractApplicationEntityIgnoresTrailingClause() {
        let applicationName = DexterApplicationLifecycleIntentParser.extractApplicationEntity(
            fromLaunchRemainder: "telegram and open settings there"
        )
        #expect(applicationName == "Telegram")
    }

    @Test func launchPlanSeparatesDestinationInApplication() {
        let plan = DexterApplicationLifecycleIntentParser.parsePlan(from: "open saved messages in telegram")
        #expect(plan?.intent.operation == .launch)
        #expect(plan?.intent.applicationName == "Telegram")
        #expect(plan?.inApplicationDestinationLabel == "Saved Messages")
    }

    @Test func launchPlanSeparatesApplicationFromCompoundGoToClause() {
        let plan = DexterApplicationLifecycleIntentParser.parsePlan(
            from: "open telegram and go to calls section there"
        )
        #expect(plan?.intent.applicationName == "Telegram")
        #expect(plan?.inApplicationDestinationLabel == nil)
    }
}
