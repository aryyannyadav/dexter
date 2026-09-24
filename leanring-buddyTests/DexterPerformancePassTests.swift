//
//  DexterPerformancePassTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterPerformancePassTests {
    @Test func trivialClassifierSkipsHeavyContextPaths() {
        #expect(DexterTrivialQuestionClassifier.isTrivialQuestion("what is a struct in Swift"))
        #expect(!DexterTrivialQuestionClassifier.isTrivialQuestion("what is this button on my screen"))
        #expect(!DexterTrivialQuestionClassifier.isTrivialQuestion("remember that I prefer dark mode"))
    }

    @Test func conversationPackagingUsesSummaryPlusRecentMessages() {
        let exchanges = (1...6).map { index in
            DexterConversationExchange(
                userTranscript: "question \(index)",
                assistantResponse: "answer \(index)"
            )
        }
        let packaged = DexterConversationPackaging.package(allExchanges: exchanges)

        #expect(packaged.recentExchangesForPrompt.count <= DexterConversationPackaging.promptExchangeLimit)
        #expect(packaged.recentExchangesForAPIHistory.count <= DexterConversationPackaging.apiHistoryExchangeLimit)
        #expect(packaged.earlierSessionSummary?.contains("Earlier in this session") == true)
    }

    @Test func pointerAnalysisSkipsOCRWhenAccessibilityIsStrong() {
        let hint = DexterAccessibilityHintAtPointer(
            roleDescription: "button",
            title: "Submit",
            valueDescription: nil,
            availability: .available
        )
        let score = DexterPointerAnalysisPolicy.accessibilityConfidenceScore(hint: hint)
        #expect(score >= 0.55)
        #expect(!DexterPointerAnalysisPolicy.shouldRunOCR(accessibilityScore: score, hasScreenshot: true))
    }

    @Test func minimalContextPlanSkipsScreenCapture() {
        let request = DexterContextAssemblyRequest(
            userMessage: "what is git",
            screenCaptureMode: .captureCursorDisplayIfPermitted,
            performanceProfile: .minimal
        )
        let plan = DexterContextCollectionPlanner.plan(for: request)
        #expect(!plan.collectScreenContext)
        #expect(!plan.collectPointer)
        #expect(!plan.collectMemory)
        #expect(plan.collectCurrentTask)
    }
}
