//
//  DexterUserTrustControls.swift
//  leanring-buddy
//

import Foundation

/// User-facing trust controls: cancel, stop, disable, revoke, clear memory.
enum DexterUserTrustControls {
    static func disableDexterAutomation(emergencyStopController: DexterEmergencyStopController) {
        emergencyStopController.activateEmergencyStop(reason: "User disabled Dexter automation.")
    }

    static func clearAllDexterMemory(memoryStore: MemoryStore) {
        memoryStore.clearSessionMemory()
        memoryStore.clearPersistentMemory(kind: nil)
        memoryStore.clearWorkflowContext()
        memoryStore.setActiveTask(description: nil, provenance: .explicitUserRequest)
    }

    static func revokeActionAutoApprove(actionPermissionSettingsStore: DexterActionPermissionSettingsStore) {
        var settings = actionPermissionSettingsStore.currentSettings
        settings.autoApproveLowRiskActions = false
        actionPermissionSettingsStore.currentSettings = settings
        actionPermissionSettingsStore.isComputerControlAuthorizedForSession = false
    }

    static func revokeProactiveAutomations(settingsStore: DexterProactiveAutomationSettingsStore) {
        var registrations = settingsStore.automationRegistrations
        for index in registrations.indices {
            registrations[index].isExplicitlyEnabledByUser = false
        }
        settingsStore.automationRegistrations = registrations
    }
}
