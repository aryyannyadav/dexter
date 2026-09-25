//
//  DexterOpenClawStructuredFailure.swift
//  leanring-buddy
//

import Foundation

/// Structured failure codes returned from OpenClaw capability / invoke boundaries.
enum DexterOpenClawStructuredFailureCode: String, Equatable, CaseIterable {
    case computerUnsupportedAction = "COMPUTER_UNSUPPORTED_ACTION"
    case capabilityNotAdvertised = "CAPABILITY_NOT_ADVERTISED"
    case gatewayDisconnected = "GATEWAY_DISCONNECTED"
    case nodeUnavailable = "NODE_UNAVAILABLE"
    case permissionDenied = "PERMISSION_DENIED"
    case invokeFailed = "INVOKE_FAILED"
    case unsupportedTool = "UNSUPPORTED_TOOL"
}

enum DexterOpenClawUserFacingFailure {
    static func message(
        for code: DexterOpenClawStructuredFailureCode,
        detail: String? = nil,
        providerLabel: String? = nil
    ) -> String {
        switch code {
        case .computerUnsupportedAction:
            if let providerLabel, !providerLabel.isEmpty {
                return "This OpenClaw provider (\(providerLabel)) doesn't support that action yet."
            }
            return "This OpenClaw provider doesn't support that action yet."
        case .capabilityNotAdvertised:
            if let detail, !detail.isEmpty {
                return "OpenClaw didn't advertise this capability: \(detail)."
            }
            return "OpenClaw didn't advertise the capability required for that action."
        case .gatewayDisconnected:
            return "OpenClaw gateway is not connected."
        case .nodeUnavailable:
            return "OpenClaw has no connected Mac node. Pair and connect Computer Control in OpenClaw."
        case .permissionDenied:
            return detail ?? "OpenClaw reported missing permissions for this action."
        case .invokeFailed:
            return detail ?? "OpenClaw could not complete that action."
        case .unsupportedTool:
            return detail ?? "Dexter does not support that tool on this runtime."
        }
    }

    static func code(for unavailableReason: DexterToolGatewayUnavailableReason) -> DexterOpenClawStructuredFailureCode {
        switch unavailableReason {
        case .openClawNotInstalled, .gatewayDisconnected:
            return .gatewayDisconnected
        case .nodeNotPaired, .nodeDisconnected:
            return .nodeUnavailable
        case .capabilityMissing:
            return .capabilityNotAdvertised
        case .applicationLifecycleControlUnavailable:
            return .computerUnsupportedAction
        case .permissionDenied:
            return .permissionDenied
        case .unsupportedTool:
            return .unsupportedTool
        }
    }
}
