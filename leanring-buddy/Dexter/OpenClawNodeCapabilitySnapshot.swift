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
struct OpenClawNodeComputerUseDescriptorSnapshot: Equatable {
    let providerIdentifier: String?
    let providerLabel: String?
    let contractVersion: Int?
    let advertisedActions: [String]

    func advertisesComputerUseAction(_ actionName: String) -> Bool {
        advertisedActions.contains(actionName)
    }

    static let unavailable = OpenClawNodeComputerUseDescriptorSnapshot(
        providerIdentifier: nil,
        providerLabel: nil,
        contractVersion: nil,
        advertisedActions: []
    )

    /// Actions Dexter maps through `OpenClawDexterToolInvokePlanner` (tests + permissive fallback when descriptor is absent).
    static let dexterMappedComputerUseActions: [String] = [
        "list_apps",
        "list_windows",
        "get_window_state",
        "get_accessibility_tree",
        "get_cursor_position",
        "launch_app",
        "kill_app",
        "bring_to_front",
        "left_click",
        "right_click",
        "double_click",
        "mouse_move",
        "left_click_drag",
        "type",
        "key",
        "scroll",
        "wait"
    ]
}

struct OpenClawNodeCapabilitySnapshot: Equatable {
    let nodeIdentifier: String
    let displayName: String?
    let isPaired: Bool
    let isConnected: Bool
    let advertisedCommands: [String]
    let computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot
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
        advertisedCommands.contains("browser.proxy") || advertisedCommands.contains("browser")
    }

    var hasFileCapabilityCommand: Bool {
        advertisedCommands.contains(where: { $0 == "file" || $0.hasPrefix("file.") })
    }

    var hasCanvasCapabilityCommand: Bool {
        advertisedCommands.contains(where: { $0 == "canvas" || $0.hasPrefix("canvas.") })
    }

    var hasMCPCapabilityCommand: Bool {
        advertisedCommands.contains(where: { $0 == "mcp" || $0.hasPrefix("mcp.") })
    }

    var hasLocalInferenceCapabilityCommand: Bool {
        advertisedCommands.contains(where: { $0 == "local-inference" || $0.hasPrefix("local-inference.") })
    }

    func advertisesNodeCommand(_ commandName: String) -> Bool {
        advertisedCommands.contains(commandName)
    }

    func advertisesCapabilityDomain(_ capability: DexterOpenClawCapabilityKind) -> Bool {
        switch capability {
        case .computerAct:
            return hasComputerActCommand
        case .screenSnapshot:
            return hasScreenSnapshotCommand
        case .browserProxy:
            return hasBrowserProxyCommand
        case .systemRun:
            return hasSystemRunCommand
        case .file:
            return hasFileCapabilityCommand
        case .canvas:
            return hasCanvasCapabilityCommand
        case .mcp:
            return hasMCPCapabilityCommand
        case .localInference:
            return hasLocalInferenceCapabilityCommand
        }
    }

    static let unavailable = OpenClawNodeCapabilitySnapshot(
        nodeIdentifier: "",
        displayName: nil,
        isPaired: false,
        isConnected: false,
        advertisedCommands: [],
        computerUseDescriptor: .unavailable,
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

        let computerUseDescriptor = OpenClawNodeComputerUseDescriptorSnapshot(
            providerIdentifier: chosenNode.computerUse?.provider?.id,
            providerLabel: chosenNode.computerUse?.provider?.label,
            contractVersion: chosenNode.computerUse?.contractVersion,
            advertisedActions: chosenNode.computerUse?.actions ?? []
        )

        return OpenClawNodeCapabilitySnapshot(
            nodeIdentifier: nodeIdentifier,
            displayName: chosenNode.displayName,
            isPaired: chosenNode.paired == true,
            isConnected: chosenNode.connected == true,
            advertisedCommands: chosenNode.commands ?? [],
            computerUseDescriptor: computerUseDescriptor,
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
    let computerUse: OpenClawNodesStatusComputerUse?
    let permissions: OpenClawNodesStatusPermissions?
}

private struct OpenClawNodesStatusComputerUse: Decodable {
    let contractVersion: Int?
    let actions: [String]?
    let provider: OpenClawNodesStatusComputerUseProvider?
}

private struct OpenClawNodesStatusComputerUseProvider: Decodable {
    let id: String?
    let label: String?
}

private struct OpenClawNodesStatusPermissions: Decodable {
    let accessibility: Bool?
    let screenRecording: Bool?
}
