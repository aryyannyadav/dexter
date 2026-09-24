//
//  OpenClawNodeCapabilitySnapshot.swift
//  leanring-buddy
//

import Foundation

struct OpenClawNodePermissionSnapshot: Equatable {
    let accessibilityGranted: Bool
    let screenRecordingGranted: Bool
    let automationGranted: Bool

    static let unavailable = OpenClawNodePermissionSnapshot(
        accessibilityGranted: false,
        screenRecordingGranted: false,
        automationGranted: false
    )
}

/// Parsed from `openclaw nodes status --json` for the preferred local Mac node.
struct OpenClawNodeCapabilitySnapshot: Equatable {
    let nodeIdentifier: String
    let displayName: String?
    let isPaired: Bool
    let isConnected: Bool
    let advertisedCommands: [String]
    let permissions: OpenClawNodePermissionSnapshot

    var hasComputerActCommand: Bool {
        advertisedCommands.contains("computer.act")
    }

    var hasSystemRunCommand: Bool {
        advertisedCommands.contains("system.run")
    }

    var hasScreenSnapshotCommand: Bool {
        advertisedCommands.contains("screen.snapshot")
    }

    var hasBrowserProxyCommand: Bool {
        advertisedCommands.contains("browser.proxy")
    }

    static let unavailable = OpenClawNodeCapabilitySnapshot(
        nodeIdentifier: "",
        displayName: nil,
        isPaired: false,
        isConnected: false,
        advertisedCommands: [],
        permissions: .unavailable
    )
}

enum OpenClawNodesStatusJSONParser {
    static func preferredLocalNodeSnapshot(from output: String) -> OpenClawNodeCapabilitySnapshot? {
        guard let data = extractJSONObjectData(from: output) else { return nil }
        guard let envelope = try? JSONDecoder().decode(OpenClawNodesStatusEnvelope.self, from: data) else {
            return nil
        }

        let nodes = envelope.nodes ?? []
        let connectedNode = nodes.first(where: { $0.connected == true })
        let chosenNode = connectedNode ?? nodes.first(where: { $0.paired == true }) ?? nodes.first
        guard let chosenNode, let nodeIdentifier = chosenNode.nodeId, !nodeIdentifier.isEmpty else {
            return nil
        }

        let permissionSnapshot = OpenClawNodePermissionSnapshot(
            accessibilityGranted: chosenNode.permissions?.accessibility == true,
            screenRecordingGranted: chosenNode.permissions?.screenRecording == true,
            automationGranted: chosenNode.permissions?.accessibility == true
        )

        return OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: nodeIdentifier,
            displayName: chosenNode.displayName,
            isPaired: chosenNode.paired == true,
            isConnected: chosenNode.connected == true,
            advertisedCommands: chosenNode.commands ?? [],
            permissions: permissionSnapshot
        )
    }

    private static func extractJSONObjectData(from output: String) -> Data? {
        guard let firstOpeningBraceIndex = output.firstIndex(of: "{"),
              let lastClosingBraceIndex = output.lastIndex(of: "}"),
              firstOpeningBraceIndex <= lastClosingBraceIndex
        else {
            return nil
        }
        let jsonCandidate = String(output[firstOpeningBraceIndex...lastClosingBraceIndex])
        return jsonCandidate.data(using: .utf8)
    }
}

private struct OpenClawNodesStatusEnvelope: Decodable {
    let nodes: [OpenClawNodesStatusNode]?
}

private struct OpenClawNodesStatusNode: Decodable {
    let nodeId: String?
    let displayName: String?
    let paired: Bool?
    let connected: Bool?
    let commands: [String]?
    let permissions: OpenClawNodesStatusPermissions?
}

private struct OpenClawNodesStatusPermissions: Decodable {
    let accessibility: Bool?
    let screenRecording: Bool?
}
