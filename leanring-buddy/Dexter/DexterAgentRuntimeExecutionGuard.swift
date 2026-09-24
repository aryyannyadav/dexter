//
//  DexterAgentRuntimeExecutionGuard.swift
//  leanring-buddy
//

import Foundation

enum DexterAgentRuntimeExecutionGuard {
    struct TimeoutError: Error, Equatable {
        let timeoutSeconds: TimeInterval
    }

    static func executeAction(
        agentRuntime: AgentRuntime,
        actionRequest: AgentActionRequest,
        timeoutSeconds: TimeInterval = 60
    ) async throws -> AgentActionResult {
        let openClawInvocationStartedAt = Date()
        return try await withThrowingTaskGroup(of: AgentActionResult.self) { group in
            group.addTask {
                try await agentRuntime.executeAction(actionRequest)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                _ = await agentRuntime.cancelCurrentAction()
                if agentRuntime.runtimeName == "OpenClaw" {
                    DexterOpenClawLog.log("task timed out")
                } else {
                    DexterObservabilityLog.tool("outcome=TIMEOUT timeout_seconds=\(Int(timeoutSeconds))")
                }
                throw TimeoutError(timeoutSeconds: timeoutSeconds)
            }

            guard let result = try await group.next() else {
                throw AgentRuntimeError.executionFailed("The action did not return a result.")
            }
            group.cancelAll()
            if agentRuntime.runtimeName == "OpenClaw" {
                DexterOpenClawLog.logTimedInvocation(
                    startedAt: openClawInvocationStartedAt,
                    detail: "executeAction action=\(actionRequest.actionIdentifier)"
                )
            } else {
                DexterTaskTraceRecorder.shared.recordLatency(
                    bucket: .tool,
                    milliseconds: Int(Date().timeIntervalSince(openClawInvocationStartedAt) * 1_000)
                )
                DexterObservabilityLog.tool("executeAction action=\(actionRequest.actionIdentifier)")
            }
            return result
        }
    }
}
