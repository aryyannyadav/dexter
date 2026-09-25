//
//  DexterRoutineExecutionBridge.swift
//  leanring-buddy
//

import Foundation

enum DexterRoutineRunKind: Equatable {
    case manual
    case scheduled
    case applicationContext
}

enum DexterRoutineExecutionBridge {
    /// Builds a bounded automation envelope for routine turns (reuses proactive limits shape).
    static func automationEnvelope(for routine: DexterRoutine) -> DexterAutomationEnvelope {
        let limits = DexterProactiveAutomationLimits(
            maxDurationSeconds: 120,
            maxActionCount: 2,
            allowedPermissions: [],
            allowedApplicationBundleIdentifiers: routine.trigger.applicationBundleIdentifier.map { [$0] } ?? [],
            stopConditions: DexterProactiveAutomationLimits.conservativeDefault.stopConditions
        )
        return limits.asAutomationEnvelope(goal: "Routine: \(routine.name) — \(routine.instruction)")
    }

    static func userMessageForRoutineExecution(_ routine: DexterRoutine) -> String {
        "[Routine: \(routine.name)] \(routine.instruction)"
    }

    static func capabilityBlockReason(
        routine: DexterRoutine,
        availableCapabilities: [DexterProductCapability]
    ) -> String? {
        let unavailable = DexterRoutineCapabilityResolver.unavailableCapabilityLabels(
            requiredCapabilityIDs: routine.requiredCapabilityIDs,
            availableCapabilities: availableCapabilities
        )
        guard !unavailable.isEmpty else { return nil }
        return "\(unavailable.joined(separator: ", ")) required."
    }
}
