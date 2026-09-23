//
//  DexterOrchestrator.swift
//  leanring-buddy
//
//  Central coordinator for context, memory, model generation, and (future) agent actions.
//

import Foundation

struct DexterModelGenerationOptions: Equatable {
    /// When set, skips `ContextProvider` capture and uses these snapshots instead.
    var screenCaptureOverride: [DexterScreenCaptureSnapshot]?
    /// When false, the model request is sent without prior conversation turns.
    var includeSessionConversationHistory: Bool

    init(
        screenCaptureOverride: [DexterScreenCaptureSnapshot]? = nil,
        includeSessionConversationHistory: Bool = true
    ) {
        self.screenCaptureOverride = screenCaptureOverride
        self.includeSessionConversationHistory = includeSessionConversationHistory
    }
}

struct DexterOrchestratorModelResponse: Equatable {
    let fullResponseText: String
    let context: DexterContext
}

@MainActor
final class DexterOrchestrator {
    let contextProvider: ContextProvider
    let modelProvider: ModelProvider
    let memoryStore: MemoryStore
    let permissionManager: PermissionManager
    let agentRuntime: AgentRuntime
    let actionVerifier: ActionVerifier

    init(
        contextProvider: ContextProvider,
        modelProvider: ModelProvider,
        memoryStore: MemoryStore,
        permissionManager: PermissionManager,
        agentRuntime: AgentRuntime,
        actionVerifier: ActionVerifier
    ) {
        self.contextProvider = contextProvider
        self.modelProvider = modelProvider
        self.memoryStore = memoryStore
        self.permissionManager = permissionManager
        self.agentRuntime = agentRuntime
        self.actionVerifier = actionVerifier
    }

    func setModelIdentifier(_ modelIdentifier: String) {
        modelProvider.setModelIdentifier(modelIdentifier)
    }

    func warmUpModelConnectionIfNeeded() {
        modelProvider.warmUpConnectionIfNeeded()
    }

    func recordConversationExchange(userTranscript: String, assistantResponse: String) {
        memoryStore.appendExchange(userTranscript: userTranscript, assistantResponse: assistantResponse)
    }

    /// Generates a model response using the configured provider. Does not mutate memory.
    func generateModelResponse(
        userTranscript: String,
        systemPrompt: String,
        options: DexterModelGenerationOptions = DexterModelGenerationOptions(),
        onTextChunk: @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> DexterOrchestratorModelResponse {
        let dexterContext: DexterContext
        if let screenCaptureOverride = options.screenCaptureOverride {
            dexterContext = DexterContext(
                screenCaptures: screenCaptureOverride,
                pointerLocationInScreenSpace: nil,
                userTranscript: userTranscript
            )
        } else {
            dexterContext = try await contextProvider.buildContext(forUserTranscript: userTranscript)
        }

        let conversationHistory: [DexterConversationExchange]
        if options.includeSessionConversationHistory {
            conversationHistory = memoryStore.recentExchanges(limit: 10)
        } else {
            conversationHistory = []
        }

        let labeledImages = dexterContext.screenCaptures.map { capture in
            let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
            return DexterModelImageInput(
                imageData: capture.imageData,
                label: capture.label + dimensionInfo
            )
        }

        let generationRequest = DexterModelGenerationRequest(
            systemPrompt: systemPrompt,
            userPrompt: userTranscript,
            images: labeledImages,
            conversationHistory: conversationHistory
        )

        let generationResult = try await modelProvider.generateStreamingResponse(
            request: generationRequest,
            onTextChunk: onTextChunk
        )

        return DexterOrchestratorModelResponse(
            fullResponseText: generationResult.fullResponseText,
            context: dexterContext
        )
    }

    /// Future ACT step: permission → runtime → verify. Not used by the voice loop yet.
    func executeVerifiedAction(
        actionRequest: AgentActionRequest,
        context: DexterContext
    ) async throws -> ActionVerificationOutcome {
        let executionResult = try await agentRuntime.executeAction(actionRequest)
        return await actionVerifier.verify(
            actionRequest: actionRequest,
            executionResult: executionResult,
            context: context
        )
    }
}

@MainActor
enum DexterOrchestratorFactory {
    static func makeDefault(workerBaseURL: String, modelIdentifier: String) -> DexterOrchestrator {
        let claudeAPI = ClaudeAPI(proxyURL: "\(workerBaseURL)/chat", model: modelIdentifier)
        let modelProvider = ClaudeModelProvider(claudeAPI: claudeAPI)
        let contextProvider = ScreenCaptureContextProvider()
        let memoryStore = SessionMemoryStore(maxSessionExchanges: 10)
        let permissionManager = DexterPermissionManager()
        let agentRuntime = OpenClawAgentRuntimeAdapter()
        let actionVerifier = UncertainActionVerifier()

        return DexterOrchestrator(
            contextProvider: contextProvider,
            modelProvider: modelProvider,
            memoryStore: memoryStore,
            permissionManager: permissionManager,
            agentRuntime: agentRuntime,
            actionVerifier: actionVerifier
        )
    }
}
