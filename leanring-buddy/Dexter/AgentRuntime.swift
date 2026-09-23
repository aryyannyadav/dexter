//
//  AgentRuntime.swift
//  leanring-buddy
//

import Foundation

/// Description of a computer/browser action requested by Dexter orchestration.
struct AgentActionRequest: Equatable {
    let actionIdentifier: String
    let parameters: [String: String]
}

/// Result reported by an agent runtime after attempting an action.
struct AgentActionResult: Equatable {
    let reportedSuccess: Bool
    let message: String
}

enum AgentRuntimeError: Error, Equatable {
    case notConfigured
    case unavailable
}

/// Executes tool/computer actions. Implementations must stay behind this boundary.
protocol AgentRuntime: AnyObject {
    var runtimeName: String { get }
    func isAvailable() -> Bool
    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult
}

/// Placeholder adapter for OpenClaw. No OpenClaw APIs are called until a real integration exists.
final class OpenClawAgentRuntimeAdapter: AgentRuntime {
    let runtimeName = "OpenClaw"

    func isAvailable() -> Bool {
        false
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        _ = actionRequest
        throw AgentRuntimeError.notConfigured
    }
}
