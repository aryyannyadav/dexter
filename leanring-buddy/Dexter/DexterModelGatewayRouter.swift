//
//  DexterModelGatewayRouter.swift
//  leanring-buddy
//

import Foundation

enum DexterModelGatewayRouter {
    private static let defaultClaudeModelIdentifier = "claude-sonnet-4-6"
    private static let defaultOpenAIModelIdentifier = "gpt-5.2-2025-12-11"

    static func userRequestedLocalPrivateProcessing(userMessage: String) -> Bool {
        let lowered = userMessage.lowercased()
        let localPrivacyPhrases = [
            "locally",
            "on my machine",
            "on device",
            "on-device",
            "private",
            "don't send to the cloud",
            "do not send to the cloud",
            "offline",
            "keep this local"
        ]
        return localPrivacyPhrases.contains { lowered.contains($0) }
    }

    static func plan(
        routingContext: DexterModelGatewayRoutingContext,
        availability: DexterModelGatewayAvailability
    ) -> DexterModelGatewayRoutePlan {
        let candidateRoutes = buildCandidateRoutes(
            routingContext: routingContext,
            availability: availability
        )

        guard let primaryRoute = candidateRoutes.first else {
            let unavailableRoute = DexterModelGatewayRoute(
                backend: .ollama,
                modelIdentifier: OllamaModelConfiguration.textModelName,
                requestedCapabilities: DexterModelCapabilitySet(.text),
                routingReason: "no_backend_available"
            )
            return DexterModelGatewayRoutePlan(primaryRoute: unavailableRoute, fallbackRoutes: [])
        }

        let fallbackRoutes = Array(candidateRoutes.dropFirst())
        return DexterModelGatewayRoutePlan(primaryRoute: primaryRoute, fallbackRoutes: fallbackRoutes)
    }

    private static func buildCandidateRoutes(
        routingContext: DexterModelGatewayRoutingContext,
        availability: DexterModelGatewayAvailability
    ) -> [DexterModelGatewayRoute] {
        if routingContext.prefersLocalPrivateProcessing {
            return localOnlyRoutes(requiresVision: routingContext.requiresVision, availability: availability)
        }

        if routingContext.requiresVision {
            return visionRoutes(routingContext: routingContext, availability: availability)
        }

        if routingContext.intentComplexity == .complex {
            return reasoningRoutes(routingContext: routingContext, availability: availability)
        }

        return fastTextRoutes(routingContext: routingContext, availability: availability)
    }

    private static func localOnlyRoutes(
        requiresVision: Bool,
        availability: DexterModelGatewayAvailability
    ) -> [DexterModelGatewayRoute] {
        var routes: [DexterModelGatewayRoute] = []
        if requiresVision, availability.isOllamaVisionModelAvailable {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .ollama,
                    modelIdentifier: OllamaModelConfiguration.visionModelName,
                    requestedCapabilities: DexterModelCapabilitySet(.local, .vision),
                    routingReason: "private_local_task_screen_understanding"
                )
            )
        } else if availability.isOllamaTextModelAvailable {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .ollama,
                    modelIdentifier: OllamaModelConfiguration.textModelName,
                    requestedCapabilities: DexterModelCapabilitySet(.local, .text, .fast),
                    routingReason: "private_local_task"
                )
            )
        }
        return routes
    }

    private static func visionRoutes(
        routingContext: DexterModelGatewayRoutingContext,
        availability: DexterModelGatewayAvailability
    ) -> [DexterModelGatewayRoute] {
        var routes: [DexterModelGatewayRoute] = []

        if availability.isOllamaVisionModelAvailable {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .ollama,
                    modelIdentifier: OllamaModelConfiguration.visionModelName,
                    requestedCapabilities: DexterModelCapabilitySet(.local, .vision),
                    routingReason: "screen_understanding_local_vision"
                )
            )
        }

        if availability.isClaudeWorkerConfigured {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .claude,
                    modelIdentifier: routingContext.preferredCloudModelIdentifier ?? defaultClaudeModelIdentifier,
                    requestedCapabilities: DexterModelCapabilitySet(.vision, .reasoning),
                    routingReason: "screen_understanding_cloud_accuracy"
                )
            )
        }

        if availability.isOpenAIConfigured {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .openAI,
                    modelIdentifier: defaultOpenAIModelIdentifier,
                    requestedCapabilities: DexterModelCapabilitySet(.vision),
                    routingReason: "screen_understanding_openai_fallback"
                )
            )
        }

        return routes
    }

    private static func reasoningRoutes(
        routingContext: DexterModelGatewayRoutingContext,
        availability: DexterModelGatewayAvailability
    ) -> [DexterModelGatewayRoute] {
        var routes: [DexterModelGatewayRoute] = []

        if availability.isClaudeWorkerConfigured {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .claude,
                    modelIdentifier: routingContext.preferredCloudModelIdentifier ?? defaultClaudeModelIdentifier,
                    requestedCapabilities: DexterModelCapabilitySet(.reasoning, .text),
                    routingReason: "complex_planning_reasoning"
                )
            )
        }

        if availability.isOllamaTextModelAvailable {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .ollama,
                    modelIdentifier: OllamaModelConfiguration.textModelName,
                    requestedCapabilities: DexterModelCapabilitySet(.local, .text, .reasoning),
                    routingReason: "complex_planning_local_fallback"
                )
            )
        }

        if availability.isOpenAIConfigured {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .openAI,
                    modelIdentifier: defaultOpenAIModelIdentifier,
                    requestedCapabilities: DexterModelCapabilitySet(.text, .reasoning),
                    routingReason: "complex_planning_openai_fallback"
                )
            )
        }

        return routes
    }

    private static func fastTextRoutes(
        routingContext: DexterModelGatewayRoutingContext,
        availability: DexterModelGatewayAvailability
    ) -> [DexterModelGatewayRoute] {
        var routes: [DexterModelGatewayRoute] = []

        if availability.isOllamaTextModelAvailable {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .ollama,
                    modelIdentifier: OllamaModelConfiguration.textModelName,
                    requestedCapabilities: DexterModelCapabilitySet(.local, .fast, .text),
                    routingReason: "simple_question_fast_local"
                )
            )
        }

        if availability.isClaudeWorkerConfigured {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .claude,
                    modelIdentifier: routingContext.preferredCloudModelIdentifier ?? defaultClaudeModelIdentifier,
                    requestedCapabilities: DexterModelCapabilitySet(.fast, .text),
                    routingReason: "simple_question_cloud_fallback"
                )
            )
        }

        if availability.isOpenAIConfigured {
            routes.append(
                DexterModelGatewayRoute(
                    backend: .openAI,
                    modelIdentifier: defaultOpenAIModelIdentifier,
                    requestedCapabilities: DexterModelCapabilitySet(.fast, .text),
                    routingReason: "simple_question_openai_fallback"
                )
            )
        }

        return routes
    }
}
