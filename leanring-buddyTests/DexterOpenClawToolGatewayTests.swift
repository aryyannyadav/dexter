//
//  DexterOpenClawToolGatewayTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct StubOpenClawLocalEnvironment: OpenClawLocalEnvironmentProviding {
    let openClawExecutableURL: URL?
}

@MainActor
final class StubOpenClawHealthMonitor: OpenClawHealthMonitoring {
    var connectionState: OpenClawGatewayConnectionState = .disconnected
    var preferredNodeSnapshot: OpenClawNodeCapabilitySnapshot = .unavailable

    func refreshHealthIfNeeded(force: Bool) async {}
}

@MainActor
final class MockOpenClawNodeInvokeClient: OpenClawNodeInvoking {
    var invokedNodeIdentifier: String?
    var invokedCommand: String?
    var invokedParametersJSON: String?
    var allInvokedParametersJSON: [String] = []
    var nextResult: OpenClawNodeInvokeResult = OpenClawNodeInvokeResult(ok: true, errorMessage: nil, combinedOutput: "")
    var resultsByCallIndex: [OpenClawNodeInvokeResult] = []
    var invokedCommands: [String] = []
    var shouldThrowCancellation = false

    func invoke(
        nodeIdentifier: String,
        command: String,
        parametersJSON: String,
        invokeTimeoutMilliseconds: Int = 60_000
    ) async throws -> OpenClawNodeInvokeResult {
        invokedNodeIdentifier = nodeIdentifier
        invokedCommand = command
        invokedParametersJSON = parametersJSON
        invokedCommands.append(command)
        allInvokedParametersJSON.append(parametersJSON)
        if shouldThrowCancellation {
            throw CancellationError()
        }
        if !resultsByCallIndex.isEmpty {
            let callIndex = invokedCommands.count - 1
            if callIndex < resultsByCallIndex.count {
                return resultsByCallIndex[callIndex]
            }
        }
        return nextResult
    }

    func cancelRunningInvoke() {}
}

struct DexterOpenClawToolGatewayTests {
    private static let testComputerUseDescriptor = OpenClawNodeComputerUseDescriptorSnapshot(
        providerIdentifier: "peekaboo",
        providerLabel: "Peekaboo",
        contractVersion: 2,
        advertisedActions: OpenClawNodeComputerUseDescriptorSnapshot.dexterMappedComputerUseActions
    )

    private static let connectedNodeSnapshot = OpenClawNodeCapabilitySnapshot(
        nodeIdentifier: "node-abc",
        displayName: "Test Mac",
        isPaired: true,
        isConnected: true,
        advertisedCommands: ["computer.act", "screen.snapshot", "browser.proxy", "system.run"],
        computerUseDescriptor: testComputerUseDescriptor,
        permissions: OpenClawNodePermissionSnapshot(
            accessibilityGranted: true,
            screenRecordingGranted: true,
            automationGranted: true
        )
    )

    @Test func capabilityDiscoveryMarksAdvertisedCommands() {
        let report = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: true,
            nodeSnapshot: Self.connectedNodeSnapshot
        )
        #expect(report.gatewayConnected)
        #expect(report.nodeConnected)
        #expect(report.isCapabilityAvailable(.computerAct))
        #expect(report.isCapabilityAvailable(.screenSnapshot))
        #expect(report.isCapabilityAvailable(.browserProxy))
        #expect(report.isCapabilityAvailable(.systemRun))
    }

    @Test func capabilityDiscoveryReportsDisconnectedNode() {
        let disconnectedSnapshot = OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-abc",
            displayName: "Test Mac",
            isPaired: true,
            isConnected: false,
            advertisedCommands: ["computer.act"],
            computerUseDescriptor: testComputerUseDescriptor,
            permissions: Self.connectedNodeSnapshot.permissions
        )
        let report = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: true,
            nodeSnapshot: disconnectedSnapshot
        )
        #expect(!report.isCapabilityAvailable(.computerAct))
    }

    @Test func capabilityDiscoveryReportsMissingCommand() {
        let snapshot = OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-abc",
            displayName: nil,
            isPaired: true,
            isConnected: true,
            advertisedCommands: ["screen.snapshot"],
            computerUseDescriptor: testComputerUseDescriptor,
            permissions: Self.connectedNodeSnapshot.permissions
        )
        let report = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: true,
            nodeSnapshot: snapshot
        )
        #expect(!report.isCapabilityAvailable(.computerAct))
        #expect(report.isCapabilityAvailable(.screenSnapshot))
    }

    @Test @MainActor func gatewayReturnsUnavailableWhenNodeDisconnected() async {
        let healthMonitor = StubOpenClawHealthMonitor()
        healthMonitor.connectionState = .connected
        healthMonitor.preferredNodeSnapshot = OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-abc",
            displayName: nil,
            isPaired: true,
            isConnected: false,
            advertisedCommands: ["computer.act"],
            computerUseDescriptor: testComputerUseDescriptor,
            permissions: Self.connectedNodeSnapshot.permissions
        )

        let gateway = Self.makeGateway(healthMonitor: healthMonitor, invokeClient: MockOpenClawNodeInvokeClient())

        let outcome = await gateway.execute(
            toolInvocation: DexterToolInvocation(
                toolKind: .launchApplication,
                actionIdentifier: DexterActionType.openApplication.rawValue,
                parameters: ["applicationName": "SampleApp"]
            )
        )

        guard case .unavailable(.nodeDisconnected) = outcome else {
            Issue.record("Expected nodeDisconnected unavailable state.")
            return
        }
    }

    @Test @MainActor func gatewayReturnsUnavailableWhenCapabilityMissing() async {
        let healthMonitor = StubOpenClawHealthMonitor()
        healthMonitor.connectionState = .connected
        healthMonitor.preferredNodeSnapshot = OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-abc",
            displayName: nil,
            isPaired: true,
            isConnected: true,
            advertisedCommands: ["computer.act"],
            computerUseDescriptor: testComputerUseDescriptor,
            permissions: Self.connectedNodeSnapshot.permissions
        )

        let gateway = Self.makeGateway(healthMonitor: healthMonitor, invokeClient: MockOpenClawNodeInvokeClient())

        let outcome = await gateway.execute(
            toolInvocation: DexterToolInvocation(
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.openURL.rawValue,
                parameters: ["url": "https://example.com"]
            )
        )

        guard case .unavailable(.capabilityMissing(.browserProxy)) = outcome else {
            Issue.record("Expected browser.proxy capability missing.")
            return
        }
    }

    @Test @MainActor func gatewayDispatchesLaunchApplicationThroughComputerAct() async {
        let healthMonitor = StubOpenClawHealthMonitor()
        healthMonitor.connectionState = .connected
        healthMonitor.preferredNodeSnapshot = Self.connectedNodeSnapshot

        let invokeClient = MockOpenClawNodeInvokeClient()
        let gateway = Self.makeGateway(healthMonitor: healthMonitor, invokeClient: invokeClient)

        let outcome = await gateway.execute(
            toolInvocation: DexterToolInvocation(
                toolKind: .launchApplication,
                actionIdentifier: DexterActionType.openApplication.rawValue,
                parameters: ["applicationName": "SampleApp"]
            )
        )

        guard case .dispatchSucceeded = outcome else {
            Issue.record("Expected dispatch success.")
            return
        }
        #expect(invokeClient.invokedCommand == "computer.act")
        #expect(invokeClient.allInvokedParametersJSON.contains(where: { $0.contains("\"action\":\"launch_app\"") }))
        #expect(invokeClient.allInvokedParametersJSON.contains(where: { $0.contains("\"app\":\"SampleApp\"") }))
    }

    @Test @MainActor func gatewayReturnsDispatchFailureFromNode() async {
        let healthMonitor = StubOpenClawHealthMonitor()
        healthMonitor.connectionState = .connected
        healthMonitor.preferredNodeSnapshot = Self.connectedNodeSnapshot

        let invokeClient = MockOpenClawNodeInvokeClient()
        invokeClient.nextResult = OpenClawNodeInvokeResult(
            ok: false,
            errorMessage: "node rejected action",
            combinedOutput: "failed"
        )

        let gateway = Self.makeGateway(healthMonitor: healthMonitor, invokeClient: invokeClient)

        let outcome = await gateway.execute(
            toolInvocation: DexterToolInvocation(
                toolKind: .quitApplication,
                actionIdentifier: DexterActionType.quitApplication.rawValue,
                parameters: ["applicationName": "SampleApp"]
            )
        )

        guard case .dispatchFailed(let message, _) = outcome else {
            Issue.record("Expected dispatch failure.")
            return
        }
        #expect(message.contains("node rejected action"))
    }

    @Test @MainActor func gatewayReturnsCancelledOutcome() async {
        let healthMonitor = StubOpenClawHealthMonitor()
        healthMonitor.connectionState = .connected
        healthMonitor.preferredNodeSnapshot = Self.connectedNodeSnapshot

        let invokeClient = MockOpenClawNodeInvokeClient()
        invokeClient.shouldThrowCancellation = true

        let gateway = Self.makeGateway(healthMonitor: healthMonitor, invokeClient: invokeClient)

        let outcome = await gateway.execute(
            toolInvocation: DexterToolInvocation(
                toolKind: .click,
                actionIdentifier: DexterActionType.click.rawValue,
                parameters: ["x": "10", "y": "20"]
            )
        )

        guard case .cancelled = outcome else {
            Issue.record("Expected cancelled outcome.")
            return
        }
    }

    @Test @MainActor func gatewayCapturesScreenSnapshotBeforeCoordinateClick() async {
        let healthMonitor = StubOpenClawHealthMonitor()
        healthMonitor.connectionState = .connected
        healthMonitor.preferredNodeSnapshot = Self.connectedNodeSnapshot

        let invokeClient = MockOpenClawNodeInvokeClient()
        invokeClient.resultsByCallIndex = [
            OpenClawNodeInvokeResult(
                ok: true,
                errorMessage: nil,
                combinedOutput: #"{"displayFrameId":"frame-1","width":1440}"#
            ),
            OpenClawNodeInvokeResult(ok: true, errorMessage: nil, combinedOutput: "")
        ]

        let gateway = Self.makeGateway(healthMonitor: healthMonitor, invokeClient: invokeClient)

        let outcome = await gateway.execute(
            toolInvocation: DexterToolInvocation(
                toolKind: .click,
                actionIdentifier: DexterActionType.click.rawValue,
                parameters: ["x": "10", "y": "20"]
            )
        )

        guard case .dispatchSucceeded = outcome else {
            Issue.record("Expected dispatch success after screen snapshot.")
            return
        }
        #expect(invokeClient.invokedCommands.first == "screen.snapshot")
        #expect(invokeClient.invokedCommands.contains("computer.act"))
        #expect(invokeClient.allInvokedParametersJSON.contains(where: { $0.contains("displayFrameId") }))
    }

    @Test func invokePlannerMapsRightClickWhenAdvertised() {
        let descriptor = OpenClawNodeComputerUseDescriptorSnapshot(
            providerIdentifier: "peekaboo",
            providerLabel: "Peekaboo",
            contractVersion: 2,
            advertisedActions: OpenClawNodeComputerUseDescriptorSnapshot.dexterMappedComputerUseActions
        )
        let plan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: DexterToolInvocation(
                toolKind: .click,
                actionIdentifier: DexterActionType.click.rawValue,
                parameters: ["x": "1", "y": "2", "clickKind": "right"]
            ),
            executionIdentifier: "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
            computerUseDescriptor: descriptor,
            advertisedCommands: Self.connectedNodeSnapshot.advertisedCommands
        )
        #expect(plan?.parametersJSON.contains("right_click") == true)
    }

    @Test func toolMapperBuildsGenericApplicationLifecyclePlans() {
        let launchPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: DexterToolInvocation(
                toolKind: .launchApplication,
                actionIdentifier: DexterActionType.openApplication.rawValue,
                parameters: ["applicationName": "SampleApp"]
            ),
            executionIdentifier: "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
            computerUseDescriptor: testComputerUseDescriptor,
            advertisedCommands: Self.connectedNodeSnapshot.advertisedCommands
        )
        #expect(launchPlan?.nodeCommand == "computer.act")
        #expect(launchPlan?.parametersJSON.contains("launch_app") == true)

        let quitPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: DexterToolInvocation(
                toolKind: .quitApplication,
                actionIdentifier: DexterActionType.quitApplication.rawValue,
                parameters: ["applicationName": "SampleApp"]
            ),
            executionIdentifier: "b2c3d4e5-f6a7-4890-bcde-f01234567890",
            computerUseDescriptor: testComputerUseDescriptor,
            advertisedCommands: Self.connectedNodeSnapshot.advertisedCommands
        )
        #expect(quitPlan?.parametersJSON.contains("kill_app") == true)
    }

    @MainActor
    private static func makeGateway(
        healthMonitor: StubOpenClawHealthMonitor,
        invokeClient: MockOpenClawNodeInvokeClient
    ) -> OpenClawDexterToolGatewayAdapter {
        let stubExecutableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dexter-openclaw-stub-\(UUID().uuidString)")
        try? Data().write(to: stubExecutableURL)
        return OpenClawDexterToolGatewayAdapter(
            localEnvironment: StubOpenClawLocalEnvironment(openClawExecutableURL: stubExecutableURL),
            healthMonitor: healthMonitor,
            nodeInvokeClient: invokeClient
        )
    }

    @Test func capabilityDiscoveryReportsPermissionDeniedForComputerAct() {
        let snapshot = OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: "node-abc",
            displayName: nil,
            isPaired: true,
            isConnected: true,
            advertisedCommands: ["computer.act"],
            computerUseDescriptor: testComputerUseDescriptor,
            permissions: OpenClawNodePermissionSnapshot(
                accessibilityGranted: false,
                screenRecordingGranted: true,
                automationGranted: false
            )
        )
        let report = DexterOpenClawCapabilityDiscovery.report(
            gatewayConnected: true,
            nodeSnapshot: snapshot
        )
        #expect(!report.isCapabilityAvailable(.computerAct))
    }
}
