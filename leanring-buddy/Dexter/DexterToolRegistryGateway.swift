//
//  DexterToolRegistryGateway.swift
//  leanring-buddy
//

import AVFoundation
import Foundation

/// Single entry point: registry metadata, validation, and execution via the existing OpenClaw tool gateway.
final class DexterToolRegistryGateway {
    private let toolGateway: DexterToolGateway
    private let unifiedToolGateway: DexterUnifiedToolGateway
    private let localEnvironment: OpenClawLocalEnvironmentProviding
    private let permissionSnapshotProvider: () -> DexterPermissionSnapshot

    init(
        toolGateway: DexterToolGateway = OpenClawDexterToolGatewayAdapter(),
        localEnvironment: OpenClawLocalEnvironmentProviding = OpenClawLocalEnvironment(),
        permissionSnapshotProvider: @escaping () -> DexterPermissionSnapshot = DexterToolRegistryGateway.makeDefaultPermissionSnapshot
    ) {
        self.toolGateway = toolGateway
        self.unifiedToolGateway = DexterUnifiedToolGateway(toolGateway: toolGateway)
        self.localEnvironment = localEnvironment
        self.permissionSnapshotProvider = permissionSnapshotProvider
    }

    func productCapabilityBuildInput(integrations: [DexterIntegration] = []) async -> DexterProductCapabilityBuildInput {
        let discoveryReport = await toolGateway.discoverCapabilities()
        let permissionSnapshot = permissionSnapshotProvider()
        return DexterProductCapabilityBuildInput(
            discoveryReport: discoveryReport,
            gatewayConnected: discoveryReport.gatewayConnected,
            hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
            hasScreenRecordingPermission: permissionSnapshot.hasScreenRecordingPermission,
            hasMicrophonePermission: permissionSnapshot.hasMicrophonePermission,
            hasScreenContentPermission: permissionSnapshot.hasScreenContentPermission,
            integrations: integrations,
            isDexterComputerControlUserAuthorized: false
        )
    }

    func availableToolDefinitions() async -> [DexterRegisteredToolDefinition] {
        let context = await buildAvailabilityContext()
        return DexterToolRegistry.availableDefinitions(context: context)
    }

    func modelToolsPromptSection() async -> String {
        let definitions = await availableToolDefinitions()
        return DexterToolRegistry.modelPromptSection(from: definitions)
    }

    func validate(proposal: DexterRegisteredToolProposal) async -> Result<DexterRegisteredToolDefinition, DexterToolRegistryValidationError> {
        guard let definition = DexterToolRegistryCatalog.definition(for: proposal.toolName) else {
            return .failure(.unknownTool(proposal.toolName))
        }

        let context = await buildAvailabilityContext()
        guard DexterToolRegistry.isAvailable(definition, context: context) else {
            return .failure(.toolNotAvailable(proposal.toolName))
        }

        if let parameterError = DexterRegisteredToolRouter.validateParameters(for: definition, proposal: proposal) {
            return .failure(parameterError)
        }

        if let policyError = DexterRegisteredToolRouter.validateExecutionPolicy(proposal: proposal) {
            return .failure(.invalidParameters(policyError))
        }

        return .success(definition)
    }

    func execute(proposal: DexterRegisteredToolProposal) async -> DexterToolGatewayOutcome {
        switch await validate(proposal: proposal) {
        case .failure(.unknownTool(let toolName)):
            return .unavailable(.unsupportedTool(toolName))
        case .failure(.toolNotAvailable(let toolName)):
            return .unavailable(.unsupportedTool("\(toolName) is not available on this machine/runtime."))
        case .failure(.invalidParameters(let message)):
            return .dispatchFailed(message: message, rawOutput: nil)
        case .success(let definition):
            if definition.name == .screenCapture {
                return .dispatchFailed(
                    message: "screen.capture is fulfilled by the context engine on demand, not direct tool execution.",
                    rawOutput: nil
                )
            }

            guard let toolInvocation = DexterRegisteredToolRouter.toolInvocation(for: proposal) else {
                return .dispatchFailed(message: "Could not map registered tool to execution.", rawOutput: nil)
            }

            let context = await buildAvailabilityContext()
            if shouldExecuteThroughOpenClaw(definition: definition, toolInvocation: toolInvocation, context: context) {
                return await routeThroughUnifiedGateway(toolInvocation: toolInvocation)
            }

            if definition.runtime == .localMac {
                return await executeLocalTool(toolInvocation: toolInvocation)
            }

            return await routeThroughUnifiedGateway(toolInvocation: toolInvocation)
        }
    }

    private func routeThroughUnifiedGateway(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        switch toolInvocation.toolKind {
        case .launchApplication, .quitApplication, .focusApplication, .listRunningApplications,
             .click, .typeText, .keyPress, .scroll:
            return await unifiedToolGateway.executeComputerAction(toolInvocation: toolInvocation)
        case .browserInteraction:
            return await unifiedToolGateway.executeBrowserAction(toolInvocation: toolInvocation)
        case .screenSnapshot, .screenObservation:
            return await unifiedToolGateway.executeScreenAction(toolInvocation: toolInvocation)
        case .systemRun:
            return await unifiedToolGateway.executeSystemAction(toolInvocation: toolInvocation)
        case .fileOperation:
            return await unifiedToolGateway.executeFileAction(toolInvocation: toolInvocation)
        case .terminalOperation:
            return await executeLocalTool(toolInvocation: toolInvocation)
        }
    }

    private func shouldExecuteThroughOpenClaw(
        definition: DexterRegisteredToolDefinition,
        toolInvocation: DexterToolInvocation,
        context: DexterToolRegistryAvailabilityContext
    ) -> Bool {
        guard definition.runtime == .localMac else { return false }
        guard toolInvocation.toolKind == .fileOperation else { return false }
        return context.discoveryReport.isCapabilityAvailable(.file)
    }

    func cancelInFlightExecution() async -> DexterToolGatewayCancellationResult {
        DexterLocalTerminalToolExecutor.shared.cancelRunningProcess()
        return await toolGateway.cancelInFlightExecution()
    }

    private func executeLocalTool(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        switch toolInvocation.toolKind {
        case .fileOperation:
            return DexterLocalFileToolExecutor.execute(toolInvocation: toolInvocation)
        case .terminalOperation:
            return await DexterLocalTerminalToolExecutor.shared.execute(toolInvocation: toolInvocation)
        default:
            return .dispatchFailed(message: "Local runtime does not support this tool.", rawOutput: nil)
        }
    }

    private static func makeDefaultPermissionSnapshot() -> DexterPermissionSnapshot {
        let microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        return DexterPermissionSnapshot(
            hasAccessibilityPermission: WindowPositionManager.hasAccessibilityPermission(),
            hasScreenRecordingPermission: WindowPositionManager.hasScreenRecordingPermission(),
            hasMicrophonePermission: microphoneAuthorized,
            hasScreenContentPermission: false
        )
    }

    private func buildAvailabilityContext() async -> DexterToolRegistryAvailabilityContext {
        let discoveryReport = await toolGateway.discoverCapabilities()
        let permissionSnapshot = permissionSnapshotProvider()
        return DexterToolRegistryAvailabilityContext(
            discoveryReport: discoveryReport,
            hasScreenRecordingPermission: permissionSnapshot.hasScreenRecordingPermission,
            hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
            isOpenClawInstalled: localEnvironment.openClawExecutableURL != nil
        )
    }
}
