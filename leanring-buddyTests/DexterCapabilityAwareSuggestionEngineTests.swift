//
//  DexterCapabilityAwareSuggestionEngineTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterCapabilityAwareSuggestionEngineTests {
    private static let connectedComputerReport = DexterOpenClawCapabilityDiscovery.report(
        gatewayConnected: true,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-1",
            displayName: "Mac",
            isPaired: true,
            isConnected: true,
            advertisedCommands: ["computer.act"],
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
    )

    @Test func githubIssuesSuggestConnectWhenGitHubDisconnected() {
        let suggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(
            from: DexterCapabilityAwareSuggestionEngine.EvaluationInput(
                userMessageText: "Check my GitHub issues.",
                integrations: [
                    DexterIntegration(
                        id: "github",
                        name: "GitHub",
                        kind: .operational,
                        connectionState: .notConnected
                    )
                ],
                capabilityDiscoveryReport: Self.connectedComputerReport,
                gatewayConnected: true
            )
        )
        #expect(suggestion?.headline == "Connect GitHub")
        #expect(suggestion?.integrationIdForSettings == "github")
    }

    @Test func openWhatsAppDoesNotSuggestWhenComputerControlAvailable() {
        let suggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(
            from: DexterCapabilityAwareSuggestionEngine.EvaluationInput(
                userMessageText: "Open WhatsApp.",
                integrations: [],
                capabilityDiscoveryReport: Self.connectedComputerReport,
                gatewayConnected: true
            )
        )
        #expect(suggestion == nil)
    }

    @Test func notionSaveSuggestConnectWhenNotionUnavailable() {
        let suggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(
            from: DexterCapabilityAwareSuggestionEngine.EvaluationInput(
                userMessageText: "Research this and save the results to Notion.",
                integrations: [
                    DexterIntegration(
                        id: "discovery-notion",
                        name: "Notion",
                        kind: .discoveryReference,
                        connectionState: .unsupported
                    )
                ],
                capabilityDiscoveryReport: Self.connectedComputerReport,
                gatewayConnected: true
            )
        )
        #expect(suggestion?.headline == "Connect Notion")
        #expect(suggestion?.integrationIdForSettings == "discovery-notion")
    }

    @Test func googleCalendarEventSuggestConnect() {
        let suggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(
            from: DexterCapabilityAwareSuggestionEngine.EvaluationInput(
                userMessageText: "Create a Google Calendar event for tomorrow.",
                integrations: [
                    DexterIntegration(
                        id: "discovery-google-calendar",
                        name: "Google Calendar",
                        kind: .discoveryReference,
                        connectionState: .unsupported
                    )
                ],
                capabilityDiscoveryReport: Self.connectedComputerReport,
                gatewayConnected: true
            )
        )
        #expect(suggestion?.headline == "Connect Google Calendar")
    }

    @Test func openAppSuggestOpenClawWhenComputerControlMissing() {
        let disconnectedReport = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: false,
            nodeSnapshot: .unavailable
        )
        let suggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(
            from: DexterCapabilityAwareSuggestionEngine.EvaluationInput(
                userMessageText: "Open Calculator",
                integrations: [],
                capabilityDiscoveryReport: disconnectedReport,
                gatewayConnected: false
            )
        )
        #expect(suggestion?.headline == "Connect OpenClaw")
    }
}
