//
//  DexterOpenClawApplicationLifecycleCapabilities.swift
//  leanring-buddy
//

import Foundation

enum DexterOpenClawComputerUseLifecycleAction: String, Equatable, CaseIterable {
    case listApps = "list_apps"
    case launchApp = "launch_app"
    case killApp = "kill_app"
    case bringToFront = "bring_to_front"
}

enum DexterOpenClawApplicationLifecycleCapabilities {
    static let lifecycleControlUnavailableMessage =
        "OpenClaw doesn't expose application lifecycle control on this provider."

    static func requiredComputerUseAction(for toolKind: DexterToolKind) -> DexterOpenClawComputerUseLifecycleAction? {
        switch toolKind {
        case .launchApplication:
            return .launchApp
        case .quitApplication:
            return .killApp
        case .focusApplication:
            return nil
        case .listRunningApplications:
            return .listApps
        default:
            return nil
        }
    }

    static func supportsToolExecution(
        toolKind: DexterToolKind,
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot
    ) -> Bool {
        switch toolKind {
        case .launchApplication:
            return computerUseDescriptor.advertisesComputerUseAction(DexterOpenClawComputerUseLifecycleAction.launchApp.rawValue)
        case .quitApplication:
            return computerUseDescriptor.advertisesComputerUseAction(DexterOpenClawComputerUseLifecycleAction.killApp.rawValue)
        case .focusApplication:
            return supportsFocusExecution(computerUseDescriptor: computerUseDescriptor)
        case .listRunningApplications:
            return computerUseDescriptor.advertisesComputerUseAction(DexterOpenClawComputerUseLifecycleAction.listApps.rawValue)
        default:
            return true
        }
    }

    static func supportsFocusExecution(
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot
    ) -> Bool {
        computerUseDescriptor.advertisesComputerUseAction(DexterOpenClawComputerUseLifecycleAction.bringToFront.rawValue)
            || computerUseDescriptor.advertisesComputerUseAction(DexterOpenClawComputerUseLifecycleAction.launchApp.rawValue)
    }

    static func unavailableReason(
        toolKind: DexterToolKind,
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot
    ) -> DexterToolGatewayUnavailableReason? {
        guard isApplicationLifecycleToolKind(toolKind) else { return nil }
        if supportsToolExecution(toolKind: toolKind, computerUseDescriptor: computerUseDescriptor) {
            return nil
        }
        return .applicationLifecycleControlUnavailable(
            providerLabel: computerUseDescriptor.providerLabel ?? computerUseDescriptor.providerIdentifier
        )
    }

    static func isApplicationLifecycleToolKind(_ toolKind: DexterToolKind) -> Bool {
        switch toolKind {
        case .launchApplication, .quitApplication, .focusApplication, .listRunningApplications:
            return true
        default:
            return false
        }
    }

    static func isApplicationLifecycleAction(_ actionRequest: AgentActionRequest) -> Bool {
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue,
             DexterActionType.quitApplication.rawValue,
             DexterActionType.focusApplication.rawValue,
             DexterActionType.listRunningApplications.rawValue:
            return true
        default:
            return false
        }
    }
}
