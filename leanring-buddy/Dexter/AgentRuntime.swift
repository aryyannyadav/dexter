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

final class OpenClawAgentRuntimeAdapter: AgentRuntime {
    let runtimeName = "OpenClaw"

    private let localEnvironment: OpenClawLocalEnvironment
    private let healthMonitor: OpenClawGatewayHealthMonitor
    private let nodeInvokeClient: OpenClawNodeInvokeClient
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    init(
        localEnvironment: OpenClawLocalEnvironment = OpenClawLocalEnvironment(),
        healthMonitor: OpenClawGatewayHealthMonitor = .shared,
        nodeInvokeClient: OpenClawNodeInvokeClient = OpenClawNodeInvokeClient()
    ) {
        self.localEnvironment = localEnvironment
        self.healthMonitor = healthMonitor
        self.nodeInvokeClient = nodeInvokeClient
    }

    func isAvailable() -> Bool {
        guard localEnvironment.openClawExecutableURL != nil,
              healthMonitor.connectionState.isConnected
        else {
            return false
        }
        return healthMonitor.preferredNodeSnapshot.isConnected
            && healthMonitor.preferredNodeSnapshot.hasComputerActCommand
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        guard localEnvironment.openClawExecutableURL != nil else {
            throw AgentRuntimeError.unavailable
        }

        await healthMonitor.refreshHealthIfNeeded(force: true)

        guard healthMonitor.connectionState.isConnected else {
            throw AgentRuntimeError.unavailable
        }

        guard OpenClawRuntimeAllowlist.isDexterSupportedAction(actionRequest) else {
            throw AgentRuntimeError.unsupportedAction(
                "Dexter does not map this action to an OpenClaw node command yet."
            )
        }

        let nodeSnapshot = healthMonitor.preferredNodeSnapshot
        guard nodeSnapshot.isPaired else {
            throw AgentRuntimeError.executionFailed(
                "OpenClaw has no paired Mac node. Open OpenClaw and pair this Mac before running computer actions."
            )
        }

        guard nodeSnapshot.isConnected else {
            throw AgentRuntimeError.executionFailed(
                "OpenClaw's Mac node is paired but not connected. Open the OpenClaw app, enable Computer Control, and reconnect this Mac."
            )
        }

        guard OpenClawRuntimeAllowlist.canExecuteOnConnectedNode(actionRequest, nodeSnapshot: nodeSnapshot) else {
            throw AgentRuntimeError.executionFailed(
                "OpenClaw's Mac node is connected but computer.act is not available."
            )
        }

        let taskIdentifier = UUID().uuidString
        DexterOpenClawLog.log("task started id=\(taskIdentifier.prefix(8))")
        DexterOpenClawLog.log("capability=computer.act")
        DexterOpenClawLog.log("execution started")

        currentExecutionStatus = .queued
        currentExecutionStatus = .running

        let executionIdentifier = UUID().uuidString
        DexterOpenClawLog.log("executionId=\(executionIdentifier.prefix(8))")

        let invokeResult: OpenClawNodeInvokeResult
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue:
            invokeResult = try await invokeApplicationLifecycleAction(
                actionRequest,
                nodeIdentifier: nodeSnapshot.nodeIdentifier,
                executionIdentifier: executionIdentifier,
                openClawActionName: "launch_app"
            )
        case DexterActionType.focusApplication.rawValue:
            invokeResult = try await invokeApplicationLifecycleAction(
                actionRequest,
                nodeIdentifier: nodeSnapshot.nodeIdentifier,
                executionIdentifier: executionIdentifier,
                openClawActionName: "launch_app"
            )
        case DexterActionType.quitApplication.rawValue:
            invokeResult = try await invokeApplicationLifecycleAction(
                actionRequest,
                nodeIdentifier: nodeSnapshot.nodeIdentifier,
                executionIdentifier: executionIdentifier,
                openClawActionName: "kill_app"
            )
        default:
            throw AgentRuntimeError.unsupportedAction(
                "Dexter does not map this action to an OpenClaw node command yet."
            )
        }

        DexterOpenClawLog.log("execution result=\(invokeResult.ok ? "ok" : "failed")")

        if invokeResult.ok {
            currentExecutionStatus = .succeeded
            DexterOpenClawLog.log("task completed")
            let applicationName = actionRequest.parameters["applicationName"] ?? "the application"
            let successMessage = successMessage(
                for: actionRequest.actionIdentifier,
                applicationName: applicationName
            )
            return AgentActionResult(
                reportedSuccess: true,
                message: successMessage,
                executionStatus: .succeeded,
                runtimeTaskIdentifier: executionIdentifier,
                rawOutput: invokeResult.combinedOutput
            )
        }

        currentExecutionStatus = .failed
        let failureMessage = invokeResult.errorMessage
            ?? invokeResult.combinedOutput.nonEmptyTrimmedValue
            ?? "OpenClaw node invoke failed."
        DexterOpenClawLog.log("task completed")
        return AgentActionResult(
            reportedSuccess: false,
            message: failureMessage,
            executionStatus: .failed,
            runtimeTaskIdentifier: executionIdentifier,
            rawOutput: invokeResult.combinedOutput
        )
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        nodeInvokeClient.cancelRunningInvoke()
        if currentExecutionStatus == .running || currentExecutionStatus == .queued {
            currentExecutionStatus = .cancelled
            DexterOpenClawLog.log("task cancelled")
            return AgentActionCancellationResult(
                didCancel: true,
                message: "Requested cancellation for the running OpenClaw node invoke."
            )
        }

        return AgentActionCancellationResult(
            didCancel: false,
            message: "OpenClaw has no running action to cancel."
        )
    }

    private func invokeApplicationLifecycleAction(
        _ actionRequest: AgentActionRequest,
        nodeIdentifier: String,
        executionIdentifier: String,
        openClawActionName: String
    ) async throws -> OpenClawNodeInvokeResult {
        let applicationName = actionRequest.parameters["applicationName"] ?? ""
        let parametersJSON: String
        switch openClawActionName {
        case "kill_app":
            parametersJSON = OpenClawComputerActRequestBuilder.killApplicationParametersJSON(
                applicationName: applicationName,
                executionIdentifier: executionIdentifier
            )
        default:
            parametersJSON = OpenClawComputerActRequestBuilder.launchApplicationParametersJSON(
                applicationName: applicationName,
                executionIdentifier: executionIdentifier
            )
        }

        return try await OpenClawComputerActExecutor.performComputerAct(
            nodeIdentifier: nodeIdentifier,
            nodeInvokeClient: nodeInvokeClient,
            parametersJSON: parametersJSON,
            executionIdentifier: executionIdentifier
        )
    }

    private func successMessage(for actionIdentifier: String, applicationName: String) -> String {
        switch actionIdentifier {
        case DexterActionType.quitApplication.rawValue:
            return "OpenClaw sent quit \(applicationName) through computer.act."
        case DexterActionType.focusApplication.rawValue:
            return "OpenClaw focused \(applicationName) through computer.act."
        default:
            return "OpenClaw opened \(applicationName) through computer.act."
        }
    }
}

private extension String {
    var nonEmptyTrimmedValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
