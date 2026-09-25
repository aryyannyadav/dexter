//
//  DexterOpenClawRuntimeCapabilityRegistryTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterOpenClawRuntimeCapabilityRegistryTests {
    @Test func discoveryOnlyMarksAdvertisedCapabilities() {
        let nodeSnapshot = OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-1",
            displayName: "Mac",
            isPaired: true,
            isConnected: true,
            advertisedCommands: ["computer.act", "screen.snapshot", "file.read", "mcp.invoke"],
            computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot(
                providerIdentifier: "peekaboo",
                providerLabel: "Peekaboo",
                contractVersion: 2,
                advertisedActions: ["launch_app"]
            ),
            permissions: OpenClawNodePermissionSnapshot(
                accessibilityGranted: true,
                screenRecordingGranted: true,
                automationGranted: true
            )
        )

        let report = DexterOpenClawRuntimeCapabilityRegistry.buildDiscoveryReport(
            gatewayConnected: true,
            nodeSnapshot: nodeSnapshot
        )

        #expect(report.isCapabilityAvailable(.computerAct))
        #expect(report.isCapabilityAvailable(.screenSnapshot))
        #expect(report.isCapabilityAvailable(.file))
        #expect(report.isCapabilityAvailable(.mcp))
        #expect(!report.isCapabilityAvailable(.browserProxy))
        #expect(!report.isCapabilityAvailable(.canvas))
    }

    @Test func structuredFailureMessageForUnsupportedComputerAction() {
        let message = DexterOpenClawUserFacingFailure.message(
            for: .computerUnsupportedAction,
            providerLabel: "Peekaboo"
        )
        #expect(message.contains("doesn't support that action yet"))
    }
}
