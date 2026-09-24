//
//  DexterIntentEngineTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterIntentEngineTests {
    @Test func quitCalculatorMapsToCloseIntent() {
        let intent = DexterIntentRouter.recognize(userMessage: "quit Calculator", context: nil)
        #expect(intent.kind == .close)
        #expect(intent.target.value == "Calculator")
        #expect(intent.confidence >= 0.9)
    }

    @Test func whatIsThisMapsToExplainPointerTarget() {
        let intent = DexterIntentRouter.recognize(userMessage: "what is this?", context: nil)
        #expect(intent.kind == .explain)
        #expect(intent.target.reference == .currentPointerTarget)
    }

    @Test func fixThisHasLowConfidenceWithoutErrorSignal() {
        let intent = DexterIntentRouter.recognize(userMessage: "fix this", context: nil)
        #expect(intent.kind == .fix)
        #expect(intent.target.reference == .currentContext)
        #expect(intent.confidence < DexterIntentRouter.minimumConfidenceToActWithoutClarification)
    }

    @Test func fixThisErrorIsComplexAndGetsPlanner() {
        let result = DexterIntentEngine.evaluate(userMessage: "Fix this error", context: nil)
        #expect(result.structuredIntent.kind == .fix)
        #expect(result.complexity == .complex)
        #expect(result.plan != nil)
        #expect(result.plan?.steps.count == 8)
        #expect(result.plan?.steps.first?.identifier == "inspect")
        #expect(!result.requiresClarification)
    }

    @Test func ambiguousFixRequestsClarification() {
        let result = DexterIntentEngine.evaluate(userMessage: "fix this", context: nil)
        #expect(result.requiresClarification)
        #expect(result.clarificationPrompt != nil)
        #expect(result.plan == nil)
    }

    @Test func simpleGreetingStaysSimpleWithoutPlanner() {
        let result = DexterIntentEngine.evaluate(userMessage: "hello", context: nil)
        #expect(result.structuredIntent.kind == .companion)
        #expect(result.complexity == .simple)
        #expect(result.plan == nil)
        #expect(!result.requiresClarification)
    }

    @Test func openApplicationMapsToOpenIntent() {
        let intent = DexterIntentRouter.recognize(userMessage: "Open Safari.", context: nil)
        #expect(intent.kind == .open)
        #expect(intent.target.value == "Safari")
    }

    @Test func responseModeMapperPreservesActForLifecycle() {
        let closeIntent = DexterIntentRouter.recognize(userMessage: "quit SampleApp", context: nil)
        #expect(DexterIntentResponseModeMapper.responseMode(for: closeIntent) == .act)
    }

    @Test func searchForQueryMapsToActForBrowserExecution() {
        let searchIntent = DexterIntentRouter.recognize(userMessage: "search for swift concurrency", context: nil)
        #expect(searchIntent.kind == .search)
        #expect(DexterIntentResponseModeMapper.responseMode(for: searchIntent) == .act)
        let plan = DexterActionPlanner.planAction(
            forUserMessage: "search for swift concurrency",
            responseMode: .act,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "search for swift concurrency")),
            demonstrationSessionStore: DexterDemonstrationSessionStore()
        )
        guard case .action(let action) = plan else {
            Issue.record("Expected browser search action from ACT planner.")
            return
        }
        #expect(action.parameters["browserAction"] == "search")
    }

    @Test func troubleshootPhraseMapsToFixWithHighConfidence() {
        let intent = DexterIntentRouter.recognize(userMessage: "why is this error happening", context: nil)
        #expect(intent.kind == .fix)
        #expect(DexterIntentResponseModeMapper.responseMode(for: intent) == .troubleshoot)
    }
}
