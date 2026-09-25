//
//  OpenClawDexterToolGatewayAdapter.swift
//  leanring-buddy
//
//  Dexter Tool Gateway → OpenClaw node commands (computer.act / browser / screen / system).
//

import Foundation

protocol OpenClawHealthMonitoring: AnyObject {
    var connectionState: OpenClawGatewayConnectionState { get }
    var preferredNodeSnapshot: OpenClawNodeCapabilitySnapshot { get }
    func refreshHealthIfNeeded(force: Bool) async
}

extension OpenClawGatewayHealthMonitor: OpenClawHealthMonitoring {}

final class OpenClawDexterToolGatewayAdapter: DexterToolGateway {
    private let localEnvironment: OpenClawLocalEnvironmentProviding
    private let healthMonitor: OpenClawHealthMonitoring
    private let nodeInvokeClient: OpenClawNodeInvoking
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    init(
        localEnvironment: OpenClawLocalEnvironmentProviding = OpenClawLocalEnvironment(),
        healthMonitor: OpenClawHealthMonitoring = OpenClawGatewayHealthMonitor.shared,
        nodeInvokeClient: OpenClawNodeInvoking = OpenClawNodeInvokeClient()
    ) {
        self.localEnvironment = localEnvironment
        self.healthMonitor = healthMonitor
        self.nodeInvokeClient = nodeInvokeClient
    }

    func discoverCapabilities() async -> DexterOpenClawCapabilityDiscoveryReport {
        await healthMonitor.refreshHealthIfNeeded(force: false)
        return DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: healthMonitor.connectionState.isConnected,
            nodeSnapshot: healthMonitor.preferredNodeSnapshot
        )
    }

    func execute(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        guard localEnvironment.openClawExecutableURL != nil else {
            return .unavailable(.openClawNotInstalled)
        }

        await healthMonitor.refreshHealthIfNeeded(force: true)
        let discoveryReport = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: healthMonitor.connectionState.isConnected,
            nodeSnapshot: healthMonitor.preferredNodeSnapshot
        )

        guard discoveryReport.gatewayConnected else {
            return .unavailable(.gatewayDisconnected)
        }

        guard discoveryReport.nodePaired else {
            return .unavailable(.nodeNotPaired)
        }

        guard discoveryReport.nodeConnected else {
            return .unavailable(.nodeDisconnected)
        }

        guard let requiredCapability = toolInvocation.toolKind.requiredOpenClawCapability else {
            return .unavailable(.unsupportedTool(toolInvocation.actionIdentifier))
        }
        guard discoveryReport.isCapabilityAvailable(requiredCapability) else {
            if let capabilityStatus = discoveryReport.capabilities.first(where: { $0.capability == requiredCapability }),
               capabilityStatus.detail.lowercased().contains("permission") {
                return .unavailable(.permissionDenied(capabilityStatus.detail))
            }
            return .unavailable(.capabilityMissing(requiredCapability))
        }

        guard let nodeIdentifier = discoveryReport.nodeIdentifier else {
            return .unavailable(.nodeDisconnected)
        }

        let executionIdentifier = OpenClawComputerUseContract.newExecutionIdentifier()
        let nodeSnapshot = healthMonitor.preferredNodeSnapshot
        let computerUseDescriptor = nodeSnapshot.computerUseDescriptor
        let enrichedToolInvocation = DexterApplicationLifecycleToolInvocationEnricher.enrich(toolInvocation)

        if let lifecycleUnavailableReason = DexterOpenClawApplicationLifecycleCapabilities.unavailableReason(
            toolKind: enrichedToolInvocation.toolKind,
            computerUseDescriptor: computerUseDescriptor
        ) {
            return .unavailable(lifecycleUnavailableReason)
        }

        guard let invokePlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: enrichedToolInvocation,
            executionIdentifier: executionIdentifier,
            computerUseDescriptor: computerUseDescriptor,
            advertisedCommands: nodeSnapshot.advertisedCommands
        ) else {
            if DexterOpenClawApplicationLifecycleCapabilities.isApplicationLifecycleToolKind(enrichedToolInvocation.toolKind) {
                return .unavailable(
                    .applicationLifecycleControlUnavailable(
                        providerLabel: computerUseDescriptor.providerLabel ?? computerUseDescriptor.providerIdentifier
                    )
                )
            }
            if enrichedToolInvocation.toolKind.requiredOpenClawCapability == .computerAct,
               !computerUseDescriptor.advertisedActions.isEmpty {
                return .unavailable(.capabilityMissing(.computerAct))
            }
            return .unavailable(.unsupportedTool(enrichedToolInvocation.actionIdentifier))
        }

        DexterOpenClawLog.log("tool gateway execute tool=\(toolInvocation.toolKind) command=\(invokePlan.nodeCommand)")
        DexterOpenClawLog.log("executionId=\(executionIdentifier.prefix(8))")

        currentExecutionStatus = .running

        do {
            let invokeResult: OpenClawNodeInvokeResult
            if invokePlan.shouldCloseComputerActExecution {
                invokeResult = try await OpenClawComputerActExecutor.performComputerAct(
                    nodeIdentifier: nodeIdentifier,
                    nodeInvokeClient: nodeInvokeClient,
                    parametersJSON: invokePlan.parametersJSON,
                    executionIdentifier: executionIdentifier
                )
            } else {
                invokeResult = try await nodeInvokeClient.invoke(
                    nodeIdentifier: nodeIdentifier,
                    command: invokePlan.nodeCommand,
                    parametersJSON: invokePlan.parametersJSON,
                    invokeTimeoutMilliseconds: OpenClawNodeInvokeTimeouts.defaultInvokeTimeoutMilliseconds
                )
            }

            if invokeResult.ok {
                currentExecutionStatus = .succeeded
                return .dispatchSucceeded(
                    runtimeTaskIdentifier: executionIdentifier,
                    rawOutput: invokeResult.combinedOutput
                )
            }

            currentExecutionStatus = .failed
            let failureMessage = invokeResult.errorMessage
                ?? invokeResult.combinedOutput.nonEmptyTrimmedValue
                ?? "OpenClaw node invoke failed."
            return .dispatchFailed(message: failureMessage, rawOutput: invokeResult.combinedOutput)
        } catch is CancellationError {
            currentExecutionStatus = .cancelled
            return .cancelled(message: "OpenClaw tool execution was cancelled.")
        } catch {
            currentExecutionStatus = .failed
            return .dispatchFailed(message: error.localizedDescription, rawOutput: nil)
        }
    }

    func cancelInFlightExecution() async -> DexterToolGatewayCancellationResult {
        nodeInvokeClient.cancelRunningInvoke()
        if currentExecutionStatus == .running || currentExecutionStatus == .queued {
            currentExecutionStatus = .cancelled
            DexterOpenClawLog.log("task cancelled")
            return DexterToolGatewayCancellationResult(
                didCancel: true,
                message: "Requested cancellation for the running OpenClaw node invoke."
            )
        }
        return DexterToolGatewayCancellationResult(
            didCancel: false,
            message: "OpenClaw has no running tool invocation to cancel."
        )
    }
}
