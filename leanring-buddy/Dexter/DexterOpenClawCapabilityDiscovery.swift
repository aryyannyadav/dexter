//
//  DexterOpenClawCapabilityDiscovery.swift
//  leanring-buddy
//

import Foundation

enum DexterOpenClawCapabilityDiscovery {
    static func report(
        gatewayConnected: Bool,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot
    ) -> DexterOpenClawCapabilityDiscoveryReport {
        let nodeReady = nodeSnapshot.isPaired && nodeSnapshot.isConnected
        let permissions = nodeSnapshot.permissions

        let capabilityStatuses = DexterOpenClawCapabilityKind.allCases.map { capability in
            status(
                for: capability,
                nodeSnapshot: nodeSnapshot,
                gatewayConnected: gatewayConnected,
                nodeReady: nodeReady,
                permissions: permissions
            )
        }

        return DexterOpenClawCapabilityDiscoveryReport(
            gatewayConnected: gatewayConnected,
            nodePaired: nodeSnapshot.isPaired,
            nodeConnected: nodeSnapshot.isConnected,
            nodeIdentifier: nodeSnapshot.nodeIdentifier.isEmpty ? nil : nodeSnapshot.nodeIdentifier,
            capabilities: capabilityStatuses
        )
    }

    private static func status(
        for capability: DexterOpenClawCapabilityKind,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot,
        gatewayConnected: Bool,
        nodeReady: Bool,
        permissions: OpenClawNodePermissionSnapshot
    ) -> DexterOpenClawCapabilityStatus {
        guard gatewayConnected else {
            return DexterOpenClawCapabilityStatus(
                capability: capability,
                isAvailable: false,
                detail: "OpenClaw gateway is not connected."
            )
        }

        guard nodeSnapshot.isPaired else {
            return DexterOpenClawCapabilityStatus(
                capability: capability,
                isAvailable: false,
                detail: "No paired OpenClaw Mac node."
            )
        }

        guard nodeSnapshot.isConnected else {
            return DexterOpenClawCapabilityStatus(
                capability: capability,
                isAvailable: false,
                detail: "OpenClaw Mac node is paired but not connected."
            )
        }

        let commandAdvertised: Bool
        switch capability {
        case .computerAct:
            commandAdvertised = nodeSnapshot.hasComputerActCommand
        case .screenSnapshot:
            commandAdvertised = nodeSnapshot.hasScreenSnapshotCommand
        case .browserProxy:
            commandAdvertised = nodeSnapshot.hasBrowserProxyCommand
        case .systemRun:
            commandAdvertised = nodeSnapshot.hasSystemRunCommand
        }

        guard commandAdvertised else {
            return DexterOpenClawCapabilityStatus(
                capability: capability,
                isAvailable: false,
                detail: "Node does not advertise \(capability.rawValue)."
            )
        }

        switch capability {
        case .computerAct:
            if !permissions.accessibilityGranted {
                return DexterOpenClawCapabilityStatus(
                    capability: capability,
                    isAvailable: false,
                    detail: "Node reports accessibility permission is not granted."
                )
            }
        case .screenSnapshot:
            if !permissions.screenRecordingGranted {
                return DexterOpenClawCapabilityStatus(
                    capability: capability,
                    isAvailable: false,
                    detail: "Node reports screen recording permission is not granted."
                )
            }
        case .browserProxy, .systemRun:
            break
        }

        return DexterOpenClawCapabilityStatus(
            capability: capability,
            isAvailable: true,
            detail: "Available on connected node."
        )
    }
}
