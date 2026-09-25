//
//  OpenClawGatewayHealthMonitorTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct OpenClawGatewayHealthMonitorTests {
    @Test func gatewayProbeJSONParserReadsReachableLoopbackURL() {
        let sampleOutput = """
        {
          "ok": true,
          "capability": "connected_no_operator_scope",
          "network": {
            "localLoopbackUrl": "ws://127.0.0.1:18789"
          }
        }
        """

        let envelope = OpenClawGatewayProbeJSONParser.parse(from: sampleOutput)
        #expect(envelope?.ok == true)
        #expect(envelope?.network?.localLoopbackUrl == "ws://127.0.0.1:18789")
    }

    @Test func openClawVersionParserReadsSemanticVersion() {
        let version = OpenClawVersionParser.parse(from: "OpenClaw 2026.9.5 (f396007)\n")
        #expect(version == "2026.9.5")
    }

    @Test func openClawRuntimeAllowlistSupportsGenericOpenApplicationIntent() {
        let request = AgentActionRequest(
            actionIdentifier: DexterActionType.openApplication.rawValue,
            parameters: ["applicationName": "Calculator"]
        )
        #expect(OpenClawRuntimeAllowlist.isDexterSupportedAction(request))
        #expect(OpenClawRuntimeAllowlist.prefersOpenClawRuntime(request))
    }

    @Test func nodesStatusJSONParserReadsConnectedNodeCapabilities() {
        let sampleOutput = """
        {
          "nodes": [
            {
              "nodeId": "abc123",
              "displayName": "Test Mac",
              "paired": true,
              "connected": true,
              "commands": ["computer.act", "screen.snapshot", "system.run", "browser.proxy"],
              "permissions": {
                "accessibility": true,
                "screenRecording": false
              }
            }
          ]
        }
        """

        let snapshot = OpenClawNodesStatusJSONParser.preferredLocalNodeSnapshot(from: sampleOutput)
        #expect(snapshot?.nodeIdentifier == "abc123")
        #expect(snapshot?.isConnected == true)
        #expect(snapshot?.hasComputerActCommand == true)
        #expect(snapshot?.hasSystemRunCommand == true)
        #expect(snapshot?.hasBrowserProxyCommand == true)
        #expect(snapshot?.hasScreenSnapshotCommand == true)
    }

    @Test func nodesInvokeJSONParserReadsFailureEnvelope() {
        let sampleOutput = """
        {
          "ok": false,
          "error": {
            "message": "node not connected"
          }
        }
        """

        let envelope = OpenClawNodesInvokeJSONParser.parse(from: sampleOutput)
        #expect(envelope?.ok == false)
        #expect(envelope?.error?.message == "node not connected")
    }

    @Test func computerActLaunchAppParametersUseOpenClawContract() {
        let parametersJSON = OpenClawComputerActRequestBuilder.launchApplicationParametersJSON(
            applicationName: "Calculator",
            executionIdentifier: "00000000-0000-4000-8000-000000000001"
        )
        #expect(parametersJSON.contains("\"action\":\"launch_app\""))
        #expect(parametersJSON.contains("\"app\":\"Calculator\""))
        #expect(parametersJSON.contains("\"executionId\":\"00000000-0000-4000-8000-000000000001\""))
    }

    @Test func computerUseExecutionIdentifierIsLowercaseUUID() {
        let executionIdentifier = OpenClawComputerUseContract.newExecutionIdentifier()
        #expect(OpenClawComputerUseContract.isValidExecutionIdentifier(executionIdentifier))
        #expect(executionIdentifier == executionIdentifier.lowercased())
    }

    @Test func clickPlanUsesLeftClickContractAction() {
        let clickPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: DexterToolInvocation(
                toolKind: .click,
                actionIdentifier: DexterActionType.click.rawValue,
                parameters: ["x": "120", "y": "340"]
            ),
            executionIdentifier: "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
            computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot(
                providerIdentifier: "peekaboo",
                providerLabel: "Peekaboo",
                contractVersion: 2,
                advertisedActions: OpenClawNodeComputerUseDescriptorSnapshot.dexterMappedComputerUseActions
            ),
            advertisedCommands: ["computer.act"]
        )
        #expect(clickPlan?.parametersJSON.contains("\"action\":\"left_click\"") == true)
        #expect(clickPlan?.parametersJSON.contains("\"x\":120") == true)
        #expect(clickPlan?.parametersJSON.contains("\"y\":340") == true)
    }
}
