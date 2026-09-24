//
//  DexterUserTurnExecutor.swift
//  leanring-buddy
//

import Foundation

/// Orchestrator-facing turn execution shared by voice and typed text.
enum DexterUserTurnExecutor {
    static func normalizedTranscript(_ rawTranscript: String) -> String {
        rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func resolvedSystemPrompt(
        baseSystemPrompt: String,
        inputChannel: DexterUserInputChannel
    ) -> String {
        switch inputChannel {
        case .pushToTalkTranscript:
            return baseSystemPrompt + DexterAISystemPrompt.voiceResponseSupplement
        case .typedText:
            return baseSystemPrompt
        }
    }

    @MainActor
    static func executeCoreRuntimeTurn(
        transcript: String,
        inputChannel: DexterUserInputChannel,
        baseSystemPrompt: String,
        options: DexterModelGenerationOptions,
        orchestrator: DexterOrchestrator,
        onTextChunk: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> DexterOrchestratorModelResponse {
        let normalizedTranscript = normalizedTranscript(transcript)
        guard !normalizedTranscript.isEmpty else {
            throw DexterUserTurnExecutorError.emptyTranscript
        }

        DexterCoreExecutionPipelineLog.log(phase: .finalTranscript, detail: "channel=\(inputChannel)")
        DexterCoreExecutionPipelineLog.log(phase: .intent)
        DexterCoreExecutionPipelineLog.log(phase: .context)

        let systemPrompt = resolvedSystemPrompt(
            baseSystemPrompt: baseSystemPrompt,
            inputChannel: inputChannel
        )

        let orchestratorResponse = try await orchestrator.generateModelResponse(
            userTranscript: normalizedTranscript,
            systemPrompt: systemPrompt,
            options: options,
            onTextChunk: onTextChunk
        )

        DexterCoreExecutionPipelineLog.log(phase: .response)
        return orchestratorResponse
    }
}

enum DexterUserTurnExecutorError: Error, Equatable {
    case emptyTranscript
}
