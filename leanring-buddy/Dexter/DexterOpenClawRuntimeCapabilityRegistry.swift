//
//  DexterOpenClawRuntimeCapabilityRegistry.swift
//  leanring-buddy
//

import Foundation

struct DexterOpenClawSettingsCapabilityRow: Identifiable, Equatable {
    let id: String
    let title: String
    let statusLabel: String
    let isAvailable: Bool
    let detail: String?
}

/// Runtime capability registry built only from gateway + node discovery (no assumed commands).
enum DexterOpenClawRuntimeCapabilityRegistry {
    static func buildDiscoveryReport(
        gatewayConnected: Bool,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot
    ) -> DexterOpenClawCapabilityDiscoveryReport {
        DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: gatewayConnected,
            nodeSnapshot: nodeSnapshot
        )
    }

    static func settingsCapabilityRows(
        discoveryReport: DexterOpenClawCapabilityDiscoveryReport,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot
    ) -> [DexterOpenClawSettingsCapabilityRow] {
        discoveryReport.capabilities
            .filter { nodeSnapshot.advertisesCapabilityDomain($0.capability) }
            .map { capabilityStatus in
            DexterOpenClawSettingsCapabilityRow(
                id: capabilityStatus.capability.rawValue,
                title: capabilityStatus.capability.settingsTitle,
                statusLabel: capabilityStatus.isAvailable ? "Available" : "Unavailable",
                isAvailable: capabilityStatus.isAvailable,
                detail: capabilityStatus.isAvailable ? nil : capabilityStatus.detail
            )
        }
    }

    static func gatewayConnectionLabel(connectionState: OpenClawGatewayConnectionState) -> String {
        switch connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting…"
        case .disconnected:
            return "Offline"
        case .unavailable:
            return "Not installed"
        case .error:
            return "Error"
        }
    }

    static func nodeConnectionLabel(nodeSnapshot: OpenClawNodeCapabilitySnapshot) -> String {
        if nodeSnapshot.isConnected {
            return "Connected"
        }
        if nodeSnapshot.isPaired {
            return "Paired (offline)"
        }
        return "Not paired"
    }
}

extension DexterOpenClawCapabilityKind {
    var settingsTitle: String {
        switch self {
        case .computerAct:
            return "Computer control"
        case .screenSnapshot:
            return "Screen"
        case .browserProxy:
            return "Browser"
        case .systemRun:
            return "System"
        case .file:
            return "Files"
        case .canvas:
            return "Canvas"
        case .mcp:
            return "MCP"
        case .localInference:
            return "Local inference"
        }
    }
}
