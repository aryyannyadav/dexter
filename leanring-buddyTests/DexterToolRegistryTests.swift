//
//  DexterToolRegistryTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

final class MockDexterToolGatewayForRegistry: DexterToolGateway {
    var discoveryReport: DexterOpenClawCapabilityDiscoveryReport
    var lastExecutedInvocation: DexterToolInvocation?

    init(discoveryReport: DexterOpenClawCapabilityDiscoveryReport) {
        self.discoveryReport = discoveryReport
    }

    func discoverCapabilities() async -> DexterOpenClawCapabilityDiscoveryReport {
        discoveryReport
    }

    func execute(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        lastExecutedInvocation = toolInvocation
        return .dispatchSucceeded(runtimeTaskIdentifier: "registry-test", rawOutput: nil)
    }

    func cancelInFlightExecution() async -> DexterToolGatewayCancellationResult {
        DexterToolGatewayCancellationResult(didCancel: false, message: "none")
    }
}

struct DexterToolRegistryTests {
    private static let connectedNodeSnapshot = OpenClawNodeCapabilitySnapshot(
        nodeIdentifier: "node-registry",
        displayName: "Registry Mac",
        isPaired: true,
        isConnected: true,
        advertisedCommands: ["computer.act", "screen.snapshot", "browser.proxy", "system.run"],
        permissions: OpenClawNodePermissionSnapshot(
            accessibilityGranted: true,
            screenRecordingGranted: true,
            automationGranted: true
        )
    )

    private static func discoveryReport(nodeConnected: Bool = true) -> DexterOpenClawCapabilityDiscoveryReport {
        let snapshot = nodeConnected
            ? connectedNodeSnapshot
            : OpenClawNodeCapabilitySnapshot(
                nodeIdentifier: connectedNodeSnapshot.nodeIdentifier,
                displayName: connectedNodeSnapshot.displayName,
                isPaired: true,
                isConnected: false,
                advertisedCommands: connectedNodeSnapshot.advertisedCommands,
                permissions: connectedNodeSnapshot.permissions
            )
        return DexterOpenClawCapabilityDiscovery.report(gatewayConnected: true, nodeSnapshot: snapshot)
    }

    private static func availabilityContext(
        discoveryReport: DexterOpenClawCapabilityDiscoveryReport,
        hasScreenRecordingPermission: Bool = true,
        hasAccessibilityPermission: Bool = true,
        isOpenClawInstalled: Bool = true
    ) -> DexterToolRegistryAvailabilityContext {
        DexterToolRegistryAvailabilityContext(
            discoveryReport: discoveryReport,
            hasScreenRecordingPermission: hasScreenRecordingPermission,
            hasAccessibilityPermission: hasAccessibilityPermission,
            isOpenClawInstalled: isOpenClawInstalled
        )
    }

    @Test func catalogDefinesEveryRegisteredToolName() {
        let catalogNames = Set(DexterToolRegistryCatalog.allDefinitions.map(\.name))
        let expectedNames = Set(DexterRegisteredToolName.allCases)
        #expect(catalogNames == expectedNames)
        #expect(catalogNames.count == 26)
    }

    @Test func fileAndTerminalToolsAvailableWithoutOpenClawNode() {
        let context = Self.availabilityContext(
            discoveryReport: Self.discoveryReport(nodeConnected: false),
            isOpenClawInstalled: false
        )
        let availableNames = Set(DexterToolRegistry.availableDefinitions(context: context).map(\.name))
        #expect(availableNames.contains(.fileRead))
        #expect(availableNames.contains(.terminalInspect))
        #expect(availableNames.contains(.screenCapture))
    }

    @Test func screenCaptureAvailableWithScreenRecordingPermissionOnly() {
        let context = Self.availabilityContext(
            discoveryReport: Self.discoveryReport(nodeConnected: false),
            hasScreenRecordingPermission: true,
            isOpenClawInstalled: false
        )
        let availableNames = DexterToolRegistry.availableDefinitions(context: context).map(\.name)
        #expect(availableNames == [.screenCapture])
    }

    @Test func openClawToolsHiddenWhenNodeDisconnected() {
        let context = Self.availabilityContext(discoveryReport: Self.discoveryReport(nodeConnected: false))
        let availableNames = Set(DexterToolRegistry.availableDefinitions(context: context).map(\.name))
        #expect(availableNames.contains(.screenCapture))
        #expect(!availableNames.contains(.applicationLaunch))
        #expect(availableNames.contains(.terminalRun))
        #expect(!availableNames.contains(.applicationLaunch))
    }

    @Test func modelPromptSectionIncludesStructuredMetadata() {
        let definition = DexterToolRegistryCatalog.definition(for: DexterRegisteredToolName.applicationLaunch.rawValue)!
        let prompt = DexterToolRegistry.modelPromptSection(from: [definition])
        #expect(prompt.contains("name: application.launch"))
        #expect(prompt.contains("requiredPermissions: accessibility"))
        #expect(prompt.contains("verificationStrategy: application_lifecycle"))
        #expect(prompt.contains("runtime: openclaw"))
    }

    @Test func validateRejectsUnknownTool() async {
        let gateway = MockDexterToolGatewayForRegistry(discoveryReport: Self.discoveryReport())
        let registryGateway = DexterToolRegistryGateway(
            toolGateway: gateway,
            localEnvironment: StubOpenClawLocalEnvironment(openClawExecutableURL: URL(fileURLWithPath: "/tmp/openclaw")),
            permissionSnapshotProvider: {
                DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: true,
                    hasMicrophonePermission: true,
                    hasScreenContentPermission: true
                )
            }
        )

        let result = await registryGateway.validate(
            proposal: DexterRegisteredToolProposal(toolName: "mouse.teleport", parameters: [:])
        )
        #expect(result == .failure(.unknownTool("mouse.teleport")))
    }

    @Test func validateRejectsToolNotAvailableOnRuntime() async {
        let gateway = MockDexterToolGatewayForRegistry(discoveryReport: Self.discoveryReport(nodeConnected: false))
        let registryGateway = DexterToolRegistryGateway(
            toolGateway: gateway,
            localEnvironment: StubOpenClawLocalEnvironment(openClawExecutableURL: URL(fileURLWithPath: "/tmp/openclaw")),
            permissionSnapshotProvider: {
                DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: true,
                    hasMicrophonePermission: true,
                    hasScreenContentPermission: true
                )
            }
        )

        let result = await registryGateway.validate(
            proposal: DexterRegisteredToolProposal(
                toolName: DexterRegisteredToolName.applicationLaunch.rawValue,
                parameters: ["applicationName": "Safari"]
            )
        )
        #expect(result == .failure(.toolNotAvailable(DexterRegisteredToolName.applicationLaunch.rawValue)))
    }

    @Test func registeredToolRouterMapsApplicationLaunch() {
        let invocation = DexterRegisteredToolRouter.toolInvocation(
            for: DexterRegisteredToolProposal(
                toolName: DexterRegisteredToolName.applicationLaunch.rawValue,
                parameters: ["applicationName": "Safari"]
            )
        )
        #expect(invocation?.registeredToolName == DexterRegisteredToolName.applicationLaunch.rawValue)
        #expect(invocation?.toolKind == .launchApplication)
        #expect(invocation?.parameters["applicationName"] == "Safari")
    }

    @Test func registryGatewayExecuteRoutesThroughUnderlyingToolGateway() async {
        let mockGateway = MockDexterToolGatewayForRegistry(discoveryReport: Self.discoveryReport())
        let registryGateway = DexterToolRegistryGateway(
            toolGateway: mockGateway,
            localEnvironment: StubOpenClawLocalEnvironment(openClawExecutableURL: URL(fileURLWithPath: "/tmp/openclaw")),
            permissionSnapshotProvider: {
                DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: true,
                    hasMicrophonePermission: true,
                    hasScreenContentPermission: true
                )
            }
        )

        let outcome = await registryGateway.execute(
            proposal: DexterRegisteredToolProposal(
                toolName: DexterRegisteredToolName.keyboardType.rawValue,
                parameters: ["text": "hello"]
            )
        )

        #expect(outcome == .dispatchSucceeded(runtimeTaskIdentifier: "registry-test", rawOutput: nil))
        #expect(mockGateway.lastExecutedInvocation?.registeredToolName == DexterRegisteredToolName.keyboardType.rawValue)
        #expect(mockGateway.lastExecutedInvocation?.parameters["text"] == "hello")
    }
}
