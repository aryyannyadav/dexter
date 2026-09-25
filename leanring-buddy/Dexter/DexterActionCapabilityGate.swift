//
//  DexterActionCapabilityGate.swift
//  leanring-buddy
//

import Foundation

enum DexterActionCapabilityGate {
    static func requiredCapabilities(for action: DexterAction) -> [DexterActionRequirement] {
        switch action.type {
        case .openApplication, .focusApplication, .quitApplication, .listRunningApplications:
            return [DexterActionRequirement(capabilityID: .computerLaunchApp, integrationID: nil)]
        case .click, .typeText, .scroll, .keyboardShortcut:
            return [DexterActionRequirement(capabilityID: .computerPointer, integrationID: nil)]
        case .openURL, .navigate, .select:
            return [DexterActionRequirement(capabilityID: .browserNavigation, integrationID: nil)]
        case .fileOperation:
            return [DexterActionRequirement(capabilityID: .filesLocal, integrationID: nil)]
        case .terminalOperation:
            return [DexterActionRequirement(capabilityID: .terminalCommands, integrationID: nil)]
        case .inspectScreen, .explainContent:
            return [DexterActionRequirement(capabilityID: .screenUnderstanding, integrationID: nil)]
        case .runTask:
            return [DexterActionRequirement(capabilityID: .computerControl, integrationID: nil)]
        }
    }

    static func evaluate(
        action: DexterAction,
        capabilities: [DexterProductCapability]
    ) -> DexterActionCapabilityGateOutcome {
        for requirement in requiredCapabilities(for: action) {
            guard let capability = DexterProductCapabilityRegistry.capability(
                for: requirement.capabilityID,
                in: capabilities
            ) else {
                continue
            }

            switch capability.availability {
            case .available:
                continue
            case .requiresConnection:
                return .blocked(
                    userMessage: "\(capability.displayName) isn't connected right now. Open Dexter Settings → Capabilities to reconnect Dexter's computer runtime."
                )
            case .requiresPermission:
                return .blocked(
                    userMessage: "\(capability.displayName) needs permission before Dexter can do that. Grant the permission in System Settings, then try again."
                )
            case .unavailable, .unsupported:
                return .blocked(
                    userMessage: "\(capability.displayName) isn't available with your current Dexter setup."
                )
            }
        }
        return .allowed
    }
}
