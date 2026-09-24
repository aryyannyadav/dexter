//
//  DexterContextRelevancePlannerTests.swift
//  leanring-buddyTests
//

import Testing
@testable import Dexter

struct DexterContextRelevancePlannerTests {
    @Test func screenCaptureRequestedForVisualQuestionsOnly() {
        #expect(DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: "What am I looking at?"))
        #expect(DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: "Explain this window."))
        #expect(DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: "What's wrong here?"))
        #expect(!DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: "hello"))
        #expect(DexterContextRelevancePlanner.shouldSkipScreenCapture(forUserMessage: "hello"))
    }
}
