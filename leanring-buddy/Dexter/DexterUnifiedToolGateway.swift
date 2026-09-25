//
//  DexterUnifiedToolGateway.swift
//  leanring-buddy
//
//  Domain-oriented facade over DexterToolGateway. SwiftUI and views must not call OpenClaw directly.
//

import Foundation

final class DexterUnifiedToolGateway {
    private let toolGateway: DexterToolGateway

    init(toolGateway: DexterToolGateway) {
        self.toolGateway = toolGateway
    }

    func discoverCapabilities() async -> DexterOpenClawCapabilityDiscoveryReport {
        await toolGateway.discoverCapabilities()
    }

    func executeComputerAction(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        await executeWhenCapabilityMatches(
            toolInvocation: toolInvocation,
            expectedCapability: .computerAct
        )
    }

    func executeBrowserAction(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        await executeWhenCapabilityMatches(
            toolInvocation: toolInvocation,
            expectedCapability: .browserProxy
        )
    }

    func executeSystemAction(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        await executeWhenCapabilityMatches(
            toolInvocation: toolInvocation,
            expectedCapability: .systemRun
        )
    }

    func executeFileAction(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        await executeWhenCapabilityMatches(
            toolInvocation: toolInvocation,
            expectedCapability: .file
        )
    }

    func executeScreenAction(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        await executeWhenCapabilityMatches(
            toolInvocation: toolInvocation,
            expectedCapability: .screenSnapshot
        )
    }

    func executeMCPAction(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        await executeWhenCapabilityMatches(
            toolInvocation: toolInvocation,
            expectedCapability: .mcp
        )
    }

    func cancelInFlightExecution() async -> DexterToolGatewayCancellationResult {
        await toolGateway.cancelInFlightExecution()
    }

    private func executeWhenCapabilityMatches(
        toolInvocation: DexterToolInvocation,
        expectedCapability: DexterOpenClawCapabilityKind
    ) async -> DexterToolGatewayOutcome {
        guard toolInvocation.toolKind.requiredOpenClawCapability == expectedCapability else {
            return .unavailable(.unsupportedTool(toolInvocation.actionIdentifier))
        }
        return await toolGateway.execute(toolInvocation: toolInvocation)
    }
}
