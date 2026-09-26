//
//  DexterModelGateway.swift
//  leanring-buddy
//
//  Routes generation across Ollama, Claude, and OpenAI with capability-aware fallback.
//  Never fabricates success — failures propagate after exhausting fallbacks.
//

import Foundation

@MainActor
final class DexterModelGateway: ModelProvider {
    private let ollamaProvider: OllamaModelProviderAdapter
    private let claudeProvider: ClaudeModelProvider?
    private let openAIProvider: OpenAIModelProvider?
    private let ollamaConnectionProvider: OllamaProvider

    private(set) var lastRoutedBackend: DexterModelBackendKind?
    private(set) var lastRouteReason: String?
    private(set) var preferredCloudModelIdentifier: String

    var uiTargetVisionProvider: VisionProvider {
        ollamaProvider.uiTargetVisionProvider
    }

    var modelIdentifier: String {
        if let lastRoutedBackend {
            switch lastRoutedBackend {
            case .ollama:
                return ollamaProvider.modelIdentifier
            case .claude:
                return claudeProvider?.modelIdentifier ?? preferredCloudModelIdentifier
            case .openAI:
                return openAIProvider?.modelIdentifier ?? "openai"
            }
        }
        return ollamaProvider.modelIdentifier
    }

    init(
        ollamaProvider: OllamaModelProviderAdapter,
        ollamaConnectionProvider: OllamaProvider,
        claudeProvider: ClaudeModelProvider?,
        openAIProvider: OpenAIModelProvider?,
        preferredCloudModelIdentifier: String = "claude-sonnet-4-6"
    ) {
        self.ollamaProvider = ollamaProvider
        self.ollamaConnectionProvider = ollamaConnectionProvider
        self.claudeProvider = claudeProvider
        self.openAIProvider = openAIProvider
        self.preferredCloudModelIdentifier = preferredCloudModelIdentifier
    }

    func setModelIdentifier(_ modelIdentifier: String) {
        preferredCloudModelIdentifier = modelIdentifier
        claudeProvider?.setModelIdentifier(modelIdentifier)
    }

    func warmUpConnectionIfNeeded() {
        ollamaProvider.warmUpConnectionIfNeeded()
        claudeProvider?.warmUpConnectionIfNeeded()
        openAIProvider?.warmUpConnectionIfNeeded()
    }

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        let routingContext = DexterModelGatewayRoutingContext(
            intentComplexity: .simple,
            prefersLocalPrivateProcessing: DexterModelGatewayPreferences.prefersLocalProcessing,
            requiresVision: !request.images.isEmpty || request.visionRequest != nil,
            preferredCloudModelIdentifier: preferredCloudModelIdentifier
        )
        return try await generateStreamingResponse(
            request: request,
            routingContext: routingContext,
            onTextChunk: onTextChunk
        )
    }

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        routingContext: DexterModelGatewayRoutingContext,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        let availability = await DexterModelGatewayAvailabilityResolver.resolve(
            ollamaProvider: ollamaConnectionProvider
        )
        let routePlan = DexterModelGatewayRouter.plan(
            routingContext: routingContext,
            availability: availability
        )

        if routePlan.orderedRoutes.isEmpty {
            throw DexterModelGatewayError.noRouteAvailable
        }

        var lastErrorDescription = "unknown"
        for (routeIndex, route) in routePlan.orderedRoutes.enumerated() {
            guard let backendProvider = provider(for: route.backend) else {
                DexterDiagnosticLog.model(
                    "gateway skip backend=\(route.backend.rawValue) reason=not_configured"
                )
                continue
            }

            backendProvider.setModelIdentifier(route.modelIdentifier)
            lastRoutedBackend = route.backend
            lastRouteReason = route.routingReason

            let capabilityList = route.requestedCapabilities.capabilities
                .map(\.rawValue)
                .sorted()
                .joined(separator: ",")
            DexterDiagnosticLog.model(
                """
                gateway route attempt=\(routeIndex + 1) backend=\(route.backend.rawValue) \
                model=\(route.modelIdentifier) capabilities=[\(capabilityList)] reason=\(route.routingReason)
                """
            )

            do {
                let result = try await backendProvider.generateStreamingResponse(
                    request: request,
                    onTextChunk: onTextChunk
                )
                DexterDiagnosticLog.model(
                    "gateway success backend=\(route.backend.rawValue) model=\(route.modelIdentifier)"
                )
                return result
            } catch {
                lastErrorDescription = error.localizedDescription
                DexterDiagnosticLog.model(
                    "gateway fallback backend=\(route.backend.rawValue) error=\(lastErrorDescription)"
                )
            }
        }

        throw DexterModelGatewayError.allBackendsFailed(lastErrorDescription: lastErrorDescription)
    }

    private func provider(for backend: DexterModelBackendKind) -> ModelProvider? {
        switch backend {
        case .ollama:
            return ollamaProvider
        case .claude:
            return claudeProvider
        case .openAI:
            return openAIProvider
        }
    }
}

extension ModelProvider {
    @MainActor
    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        routingContext: DexterModelGatewayRoutingContext,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        if let gateway = self as? DexterModelGateway {
            return try await gateway.generateStreamingResponse(
                request: request,
                routingContext: routingContext,
                onTextChunk: onTextChunk
            )
        }
        return try await generateStreamingResponse(request: request, onTextChunk: onTextChunk)
    }
}
