//
//  leanring_buddyTests.swift
//  leanring-buddyTests
//
//  Created by thorfinn on 3/2/26.
//

import Testing
@testable import Dexter

@MainActor
struct leanring_buddyTests {

    @Test func firstPermissionRequestUsesSystemPromptOnly() async throws {
        let presentationDestination = WindowPositionManager.permissionRequestPresentationDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: false
        )

        #expect(presentationDestination == .systemPrompt)
    }

    @Test func repeatedPermissionRequestOpensSystemSettings() async throws {
        let presentationDestination = WindowPositionManager.permissionRequestPresentationDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: true
        )

        #expect(presentationDestination == .systemSettings)
    }

    @Test func knownGrantedScreenRecordingPermissionSkipsTheGate() async throws {
        let shouldTreatPermissionAsGranted = WindowPositionManager.shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch(
            hasScreenRecordingPermissionNow: false,
            hasPreviouslyConfirmedScreenRecordingPermission: true
        )

        #expect(shouldTreatPermissionAsGranted)
    }

    @Test func sessionMemoryStoreKeepsOnlyTheMostRecentExchanges() async throws {
        let memoryStore = SessionMemoryStore(maxSessionExchanges: 2)

        memoryStore.appendExchange(userTranscript: "one", assistantResponse: "a")
        memoryStore.appendExchange(userTranscript: "two", assistantResponse: "b")
        memoryStore.appendExchange(userTranscript: "three", assistantResponse: "c")

        let recentExchanges = memoryStore.recentExchanges(limit: 10)

        #expect(recentExchanges.count == 2)
        #expect(recentExchanges.first?.userTranscript == "two")
        #expect(recentExchanges.last?.userTranscript == "three")
    }

    @MainActor
    @Test func dexterOrchestratorRecordsConversationThroughMemoryStore() async throws {
        let modelProvider = MockModelProvider()
        let orchestrator = DexterOrchestrator(
            contextProvider: EmptyContextProvider(),
            modelProvider: modelProvider,
            memoryStore: SessionMemoryStore(maxSessionExchanges: 5),
            permissionManager: DexterPermissionManager(),
            agentRuntime: OpenClawAgentRuntimeAdapter(),
            actionVerifier: UncertainActionVerifier()
        )

        let response = try await orchestrator.generateModelResponse(
            userTranscript: "hello",
            systemPrompt: "test",
            options: DexterModelGenerationOptions(
                screenCaptureOverride: [],
                includeSessionConversationHistory: false
            )
        )

        #expect(response.fullResponseText == "mock-response")
        orchestrator.recordConversationExchange(userTranscript: "hello", assistantResponse: "spoken")
        #expect(orchestrator.memoryStore.recentExchanges(limit: 1).first?.assistantResponse == "spoken")
    }

}

@MainActor
private final class EmptyContextProvider: ContextProvider {
    func buildContext(forUserTranscript userTranscript: String) async throws -> DexterContext {
        DexterContext(userTranscript: userTranscript)
    }
}

@MainActor
private final class MockModelProvider: ModelProvider {
    var modelIdentifier: String = "mock"

    func setModelIdentifier(_ modelIdentifier: String) {
        self.modelIdentifier = modelIdentifier
    }

    func warmUpConnectionIfNeeded() {}

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        await onTextChunk("mock")
        return DexterModelGenerationResult(fullResponseText: "mock-response", duration: 0)
    }
}
