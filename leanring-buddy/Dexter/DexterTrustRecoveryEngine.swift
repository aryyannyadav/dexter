//
//  DexterTrustRecoveryEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterTrustRecoveryEngine {
    static func recoverToSafeIdle(
        emergencyStopController: DexterEmergencyStopController,
        clearPendingConfirmations: () -> Void,
        cancelInFlightActions: () async -> Void,
        stopSpokenOutput: () -> Void
    ) async -> String {
        emergencyStopController.beginRecovery()
        stopSpokenOutput()
        clearPendingConfirmations()
        await cancelInFlightActions()
        emergencyStopController.completeRecoveryToIdle()

        return "Dexter is in a safe idle state. You can take over manually. Re-enable Dexter when you are ready."
    }
}
