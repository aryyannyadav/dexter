//
//  DexterModelGatewayTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterModelGatewayTests {
    private let fullAvailability = DexterModelGatewayAvailability(
        isOllamaReachable: true,
        isOllamaVisionModelAvailable: true,
        isOllamaTextModelAvailable: true,
        isClaudeWorkerConfigured: true,
        isOpenAIConfigured: true
    )

    @Test func simpleQuestionPrefersFastLocalOllama() {
        let context = DexterModelGatewayRoutingContext(
            intentComplexity: .simple,
            prefersLocalPrivateProcessing: false,
            requiresVision: false,
            preferredCloudModelIdentifier: "claude-sonnet-4-6"
        )
        let plan = DexterModelGatewayRouter.plan(routingContext: context, availability: fullAvailability)
        #expect(plan.primaryRoute.backend == .ollama)
        #expect(plan.primaryRoute.modelIdentifier == OllamaModelConfiguration.textModelName)
        #expect(plan.primaryRoute.requestedCapabilities.contains(.fast))
    }

    @Test func screenUnderstandingPrefersLocalVision() {
        let context = DexterModelGatewayRoutingContext(
            intentComplexity: .simple,
            prefersLocalPrivateProcessing: false,
            requiresVision: true,
            preferredCloudModelIdentifier: nil
        )
        let plan = DexterModelGatewayRouter.plan(routingContext: context, availability: fullAvailability)
        #expect(plan.primaryRoute.backend == .ollama)
        #expect(plan.primaryRoute.modelIdentifier == OllamaModelConfiguration.visionModelName)
        #expect(plan.primaryRoute.requestedCapabilities.contains(.vision))
        #expect(plan.fallbackRoutes.contains { $0.backend == .claude })
    }

    @Test func complexPlanningPrefersClaudeReasoning() {
        let context = DexterModelGatewayRoutingContext(
            intentComplexity: .complex,
            prefersLocalPrivateProcessing: false,
            requiresVision: false,
            preferredCloudModelIdentifier: "claude-opus-4-6"
        )
        let plan = DexterModelGatewayRouter.plan(routingContext: context, availability: fullAvailability)
        #expect(plan.primaryRoute.backend == .claude)
        #expect(plan.primaryRoute.modelIdentifier == "claude-opus-4-6")
        #expect(plan.primaryRoute.requestedCapabilities.contains(.reasoning))
    }

    @Test func privateLocalTaskSkipsCloudBackends() {
        let context = DexterModelGatewayRoutingContext(
            intentComplexity: .complex,
            prefersLocalPrivateProcessing: true,
            requiresVision: false,
            preferredCloudModelIdentifier: "claude-sonnet-4-6"
        )
        let plan = DexterModelGatewayRouter.plan(routingContext: context, availability: fullAvailability)
        #expect(plan.orderedRoutes.allSatisfy { $0.backend == .ollama })
        #expect(plan.orderedRoutes.allSatisfy { $0.requestedCapabilities.contains(.local) })
    }

    @Test func userMessageCanRequestLocalProcessing() {
        #expect(DexterModelGatewayRouter.userRequestedLocalPrivateProcessing(userMessage: "answer this locally please"))
        #expect(!DexterModelGatewayRouter.userRequestedLocalPrivateProcessing(userMessage: "what time is it"))
    }
}
