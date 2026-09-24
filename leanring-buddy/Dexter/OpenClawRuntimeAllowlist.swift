//
//  OpenClawRuntimeAllowlist.swift
//  leanring-buddy
//

import Foundation

/// Dexter actions that can be executed through OpenClaw when the local node is connected.
enum OpenClawRuntimeAllowlist {
    static func isDexterSupportedAction(_ actionRequest: AgentActionRequest) -> Bool {
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue,
             DexterActionType.focusApplication.rawValue,
             DexterActionType.quitApplication.rawValue:
            let applicationName = actionRequest.parameters["applicationName"] ?? ""
            return !applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case DexterActionType.click.rawValue:
            let xCoordinate = actionRequest.parameters["x"] ?? ""
            let yCoordinate = actionRequest.parameters["y"] ?? ""
            return Double(xCoordinate) != nil && Double(yCoordinate) != nil
        default:
            return false
        }
    }

    static func canExecuteOnConnectedNode(
        _ actionRequest: AgentActionRequest,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot
    ) -> Bool {
        guard nodeSnapshot.isConnected, nodeSnapshot.hasComputerActCommand else {
            return false
        }
        return isDexterSupportedAction(actionRequest)
    }

    /// Open-application intents should route through OpenClaw before MacDexter when the node can execute them.
    static func prefersOpenClawRuntime(_ actionRequest: AgentActionRequest) -> Bool {
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue,
             DexterActionType.focusApplication.rawValue,
             DexterActionType.quitApplication.rawValue,
             DexterActionType.click.rawValue:
            return true
        default:
            return false
        }
    }
}
