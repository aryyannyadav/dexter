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
        try await withThrowingTaskGroup(of: AgentActionResult.self) { group in
            group.addTask {
                try await agentRuntime.executeAction(actionRequest)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                _ = await agentRuntime.cancelCurrentAction()
                if agentRuntime.runtimeName == "OpenClaw" {
                    DexterOpenClawLog.log("task timed out")
                }
                throw TimeoutError(timeoutSeconds: timeoutSeconds)
            }

            guard let result = try await group.next() else {
                throw AgentRuntimeError.executionFailed("The action did not return a result.")
            }
            group.cancelAll()
            return result
        }
    }
}
