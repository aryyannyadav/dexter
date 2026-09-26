//
//  DexterPerformancePassTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterCursorAccentColorTests {
    @Test func cursorAccentColorOptionsIncludePastelPinkInDisplayOrder() {
        let options = DexterCursorAccentColorOption.allCases
        #expect(options.count == 6)
        #expect(options.map(\.displayName) == [
            "Red",
            "Companion Sky",
            "Yellow",
            "Green",
            "Pastel Pink",
            "Companion Lavender"
        ])
    }

    @Test func cursorAccentColorPersistenceRoundTripsThroughRawValue() {
        for option in DexterCursorAccentColorOption.allCases {
            #expect(DexterCursorAccentColorOption(rawValue: option.rawValue) == option)
            #expect(!option.overlayTintHex.isEmpty)
        }
        #expect(DexterCursorAccentColorOption.pastelPink.overlayTintHex == "#F2B5C6")
    }
}

struct DexterPerformancePassTests {
    @Test func trivialClassifierSkipsHeavyContextPaths() {
        #expect(DexterTrivialQuestionClassifier.isTrivialQuestion("what is a struct in Swift"))
        #expect(!DexterTrivialQuestionClassifier.isTrivialQuestion("what is this button on my screen"))
        #expect(!DexterTrivialQuestionClassifier.isTrivialQuestion("remember that I prefer dark mode"))
    }

    @Test func fastRequestRouterUsesFastChatForGreetingsAndConcepts() {
        let helloRoute = DexterFastRequestRouter.route(userMessage: "hey")
        #expect(helloRoute.route == .fastChat)
        #expect(!helloRoute.requiresScreenCapture)
        #expect(helloRoute.contextPerformanceProfile == .minimal)

        let polymorphismRoute = DexterFastRequestRouter.route(userMessage: "what is polymorphism?")
        #expect(polymorphismRoute.route == .fastChat)
        #expect(!polymorphismRoute.requiresScreenCapture)

        let conceptRoute = DexterFastRequestRouter.route(userMessage: "explain this concept")
        #expect(conceptRoute.route == .fastChat)
        #expect(!conceptRoute.requiresScreenCapture)
    }

    @Test func fastRequestRouterUsesScreenContextForVisualQuestions() {
        let screenRoute = DexterFastRequestRouter.route(userMessage: "what is on my screen?")
        #expect(screenRoute.route == .screenContext)
        #expect(screenRoute.requiresScreenCapture)

        let deicticRoute = DexterFastRequestRouter.route(userMessage: "what is this button?")
        #expect(deicticRoute.route == .screenContext)
        #expect(deicticRoute.requiresScreenCapture)

        let fixThisRoute = DexterFastRequestRouter.route(userMessage: "fix this")
        #expect(fixThisRoute.route == .screenContext)

        let explainThisRoute = DexterFastRequestRouter.route(userMessage: "explain this")
        #expect(explainThisRoute.route == .screenContext)

        let nextStepRoute = DexterFastRequestRouter.route(userMessage: "what should i do next")
        #expect(nextStepRoute.route == .screenContext)

        let pointInvokeRoute = DexterFastRequestRouter.route(
            userMessage: "hey",
            forcePointInvokeScreenRoute: true
        )
        #expect(pointInvokeRoute.route == .screenContext)
        #expect(pointInvokeRoute.pinPointerForContext)
    }

    @Test func fastRequestRouterUsesComputerActionWithoutScreenCapture() {
        let openRoute = DexterFastRequestRouter.route(userMessage: "Open WhatsApp")
        #expect(openRoute.route == .computerAction)
        #expect(!openRoute.requiresScreenCapture)

        let explainConstructorsRoute = DexterFastRequestRouter.route(userMessage: "explain constructors.")
        #expect(explainConstructorsRoute.route == .fastChat)
        #expect(!explainConstructorsRoute.requiresScreenCapture)
    }

    @Test func fastRequestRouterDetectsIntegrationAndTeachingRoutes() {
        let integrationRoute = DexterFastRequestRouter.route(userMessage: "check my Gmail")
        #expect(integrationRoute.route == .integrationAgent)

        let teachingRoute = DexterFastRequestRouter.route(userMessage: "walk me through this settings panel")
        #expect(teachingRoute.route == .teaching)
        #expect(teachingRoute.requiresScreenCapture)
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
