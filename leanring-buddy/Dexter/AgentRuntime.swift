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

enum AgentActionExecutionStatus: Equatable {
    case idle
    case queued
    case running
    case succeeded
    case failed
    case cancelled
}

/// Result reported by an agent runtime after attempting an action.
struct AgentActionResult: Equatable {
    let reportedSuccess: Bool
    let message: String
    let executionStatus: AgentActionExecutionStatus
    let runtimeTaskIdentifier: String?
    let rawOutput: String?
}

struct AgentActionCancellationResult: Equatable {
    let didCancel: Bool
    let message: String
}

enum AgentRuntimeError: Error, Equatable {
    case notConfigured
    case unavailable
    case unsupportedAction(String)
    case executionFailed(String)
}

extension AgentRuntimeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The agent runtime is not configured."
        case .unavailable:
            return "The agent runtime is unavailable."
        case .unsupportedAction(let message):
            return message
        case .executionFailed(let message):
            return message
        }
    }
}

/// Executes tool/computer actions. Implementations must stay behind this boundary.
protocol AgentRuntime: AnyObject {
    var runtimeName: String { get }
    var currentExecutionStatus: AgentActionExecutionStatus { get }
    func isAvailable() -> Bool
    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult
    func cancelCurrentAction() async -> AgentActionCancellationResult
}

/// OpenClaw-backed runtime: maps approved `AgentActionRequest` values through the Dexter Tool Gateway.
final class OpenClawAgentRuntimeAdapter: AgentRuntime {
    let runtimeName = "OpenClaw"

    private let toolGateway: DexterToolGateway
    private let toolRegistryGateway: DexterToolRegistryGateway
    private let localEnvironment: OpenClawLocalEnvironmentProviding
    private let healthMonitor: OpenClawHealthMonitoring

    var currentExecutionStatus: AgentActionExecutionStatus {
        (toolGateway as? OpenClawDexterToolGatewayAdapter)?.currentExecutionStatus ?? .idle
    }

    init(
        localEnvironment: OpenClawLocalEnvironmentProviding = OpenClawLocalEnvironment(),
        healthMonitor: OpenClawHealthMonitoring = OpenClawGatewayHealthMonitor.shared,
        toolGateway: DexterToolGateway? = nil,
        toolRegistryGateway: DexterToolRegistryGateway? = nil
    ) {
        self.localEnvironment = localEnvironment
        self.healthMonitor = healthMonitor
        let resolvedToolGateway = toolGateway ?? OpenClawDexterToolGatewayAdapter(
            localEnvironment: localEnvironment,
            healthMonitor: healthMonitor
        )
        self.toolGateway = resolvedToolGateway
        self.toolRegistryGateway = toolRegistryGateway ?? DexterToolRegistryGateway(toolGateway: resolvedToolGateway)
    }

    func isAvailable() -> Bool {
        guard localEnvironment.openClawExecutableURL != nil,
              healthMonitor.connectionState.isConnected
        else {
            return false
        }
        return healthMonitor.preferredNodeSnapshot.isConnected
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        guard let toolProposal = DexterTool.registeredToolProposal(from: actionRequest) else {
            throw AgentRuntimeError.unsupportedAction(
                "Dexter does not map this action to a registered tool."
            )
        }

        switch await toolRegistryGateway.validate(proposal: toolProposal) {
        case .failure(.unknownTool(let toolName)):
            throw AgentRuntimeError.unsupportedAction("Unknown registered tool: \(toolName).")
        case .failure(.toolNotAvailable(let toolName)):
            throw AgentRuntimeError.executionFailed("\(toolName) is not available on this machine/runtime.")
        case .failure(.invalidParameters(let message)):
            throw AgentRuntimeError.unsupportedAction(message)
        case .success:
            break
        }

        guard let toolInvocation = DexterTool.invocation(from: actionRequest) else {
            throw AgentRuntimeError.unsupportedAction(
                "Dexter could not build a tool invocation for this action."
            )
        }

        let taskIdentifier = UUID().uuidString
        DexterOpenClawLog.log("task started id=\(taskIdentifier.prefix(8))")
        if let capability = toolInvocation.toolKind.requiredOpenClawCapability {
            DexterOpenClawLog.log("capability=\(capability.rawValue)")
        } else {
            DexterOpenClawLog.log("capability=local_mac")
        }

        let gatewayOutcome = await toolRegistryGateway.execute(proposal: toolProposal)

        switch gatewayOutcome {
        case .dispatchSucceeded(let runtimeTaskIdentifier, let rawOutput):
            DexterOpenClawLog.log("execution result=ok")
            DexterOpenClawLog.log("task completed")
            return AgentActionResult(
                reportedSuccess: true,
                message: dispatchMessage(for: toolInvocation),
                executionStatus: .succeeded,
                runtimeTaskIdentifier: runtimeTaskIdentifier,
                rawOutput: rawOutput
            )

        case .dispatchFailed(let message, let rawOutput):
            let structuredFailureCode = DexterOpenClawStructuredFailureParser.failureCode(
                fromMessage: message,
                rawOutput: rawOutput
            )
            if let structuredFailureCode {
                DexterOpenClawLog.log("execution result=failed code=\(structuredFailureCode.rawValue)")
            } else {
                DexterOpenClawLog.log("execution result=failed")
            }
            DexterOpenClawLog.log("task completed")
            let userFacingMessage = DexterOpenClawExecutionFailureMessage.userFacingMessage(
                actionRequest: actionRequest,
                gatewayMessage: message,
                structuredFailureCode: structuredFailureCode
            )
            return AgentActionResult(
                reportedSuccess: false,
                message: userFacingMessage,
                executionStatus: .failed,
                runtimeTaskIdentifier: nil,
                rawOutput: rawOutput
            )

        case .unavailable(let reason):
            throw AgentRuntimeError.executionFailed(unavailableMessage(for: reason))

        case .cancelled(let message):
            return AgentActionResult(
                reportedSuccess: false,
                message: message,
                executionStatus: .cancelled,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        }
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        let cancellation = await toolRegistryGateway.cancelInFlightExecution()
        return AgentActionCancellationResult(
            didCancel: cancellation.didCancel,
            message: cancellation.message
        )
    }

    private func dispatchMessage(for toolInvocation: DexterToolInvocation) -> String {
        if let capability = toolInvocation.toolKind.requiredOpenClawCapability {
            return "Dexter sent \(toolInvocation.actionIdentifier) to OpenClaw (\(capability.rawValue)); verifying the result on your Mac."
        }
        return "Dexter sent \(toolInvocation.actionIdentifier) to the local tool runtime; verifying the result."
    }

    private func unavailableMessage(for reason: DexterToolGatewayUnavailableReason) -> String {
        let failureCode = DexterOpenClawUserFacingFailure.code(for: reason)
        switch reason {
        case .openClawNotInstalled:
            return "OpenClaw is not installed on this Mac."
        case .gatewayDisconnected:
            return DexterOpenClawUserFacingFailure.message(for: failureCode)
        case .nodeNotPaired, .nodeDisconnected:
            return DexterOpenClawUserFacingFailure.message(for: failureCode)
        case .capabilityMissing(let capability):
            return DexterOpenClawUserFacingFailure.message(
                for: failureCode,
                detail: capability.settingsTitle
            )
        case .applicationLifecycleControlUnavailable(let providerLabel):
            return DexterOpenClawUserFacingFailure.message(
                for: .computerUnsupportedAction,
                providerLabel: providerLabel
            )
        case .permissionDenied(let detail):
            return DexterOpenClawUserFacingFailure.message(for: .permissionDenied, detail: detail)
        case .unsupportedTool(let actionIdentifier):
            return DexterOpenClawUserFacingFailure.message(
                for: .unsupportedTool,
                detail: actionIdentifier
            )
        }
    }
}
