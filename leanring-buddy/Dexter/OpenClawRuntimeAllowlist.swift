//
//  OpenClawRuntimeAllowlist.swift
//  leanring-buddy
//

import Foundation

/// Dexter actions that can be executed through OpenClaw when the local node exposes the required capability.
enum OpenClawRuntimeAllowlist {
    static func isDexterSupportedAction(_ actionRequest: AgentActionRequest) -> Bool {
        DexterTool.isOpenClawToolingSupported(actionRequest)
    }

    static func canExecuteOnConnectedNode(
        _ actionRequest: AgentActionRequest,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot
    ) -> Bool {
        guard let toolInvocation = DexterTool.invocation(from: actionRequest) else {
            return false
        }
        guard nodeSnapshot.isConnected else { return false }

        let discoveryReport = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: true,
            nodeSnapshot: nodeSnapshot
        )
        guard let capability = toolInvocation.toolKind.requiredOpenClawCapability else {
            return false
        }
        return discoveryReport.isCapabilityAvailable(capability)
    }

    /// Lifecycle and pointer actions should route through OpenClaw before MacDexter when the node can execute them.
    static func prefersOpenClawRuntime(_ actionRequest: AgentActionRequest) -> Bool {
        guard let toolKind = DexterTool.toolKind(for: actionRequest) else {
            return false
        }
        switch toolKind {
        case .launchApplication, .quitApplication, .focusApplication, .click, .typeText, .keyPress, .scroll,
             .browserInteraction, .screenSnapshot, .screenObservation, .systemRun:
            return true
        case .fileOperation, .terminalOperation:
            return false
        }
    }
}
