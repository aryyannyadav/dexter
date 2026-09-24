//
//  DexterToolGateway.swift
//  leanring-buddy
//

import Foundation

enum DexterToolGatewayUnavailableReason: Equatable {
    case openClawNotInstalled
    case gatewayDisconnected
    case nodeNotPaired
    case nodeDisconnected
    case capabilityMissing(DexterOpenClawCapabilityKind)
    case permissionDenied(String)
    case unsupportedTool(String)
}

enum DexterToolGatewayOutcome: Equatable {
    case dispatchSucceeded(runtimeTaskIdentifier: String, rawOutput: String?)
    case dispatchFailed(message: String, rawOutput: String?)
    case unavailable(DexterToolGatewayUnavailableReason)
    case cancelled(message: String)
}

struct DexterOpenClawCapabilityStatus: Equatable {
    let capability: DexterOpenClawCapabilityKind
    let isAvailable: Bool
    let detail: String
}

struct DexterOpenClawCapabilityDiscoveryReport: Equatable {
    let gatewayConnected: Bool
    let nodePaired: Bool
    let nodeConnected: Bool
    let nodeIdentifier: String?
    let capabilities: [DexterOpenClawCapabilityStatus]

    func isCapabilityAvailable(_ capability: DexterOpenClawCapabilityKind) -> Bool {
        capabilities.first(where: { $0.capability == capability })?.isAvailable == true
    }
}

/// Executes approved Dexter tools against the local OpenClaw node (models never call this directly).
protocol DexterToolGateway: AnyObject {
    func discoverCapabilities() async -> DexterOpenClawCapabilityDiscoveryReport
    func execute(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome
    func cancelInFlightExecution() async -> DexterToolGatewayCancellationResult
}

struct DexterToolGatewayCancellationResult: Equatable {
    let didCancel: Bool
    let message: String
}
