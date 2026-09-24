//
//  DexterEmergencyStopController.swift
//  leanring-buddy
//

import Foundation

/// Global kill switch — user can always stop Dexter immediately.
@MainActor
final class DexterEmergencyStopController {
    static let shared = DexterEmergencyStopController()

    private(set) var runtimeState: DexterAutomationRuntimeState = .stopped
    private(set) var isEmergencyStopActive = false
    private(set) var lastStopReason: String?

    private init() {}

    var blocksAllAutomation: Bool {
        isEmergencyStopActive || runtimeState == .stopping
    }

    func activateEmergencyStop(reason: String) {
        lastStopReason = reason
        isEmergencyStopActive = true
        runtimeState = .stopping
        DexterAutomationRuntimeStateLog.log(state: .stopping, detail: reason)
        runtimeState = .stopped
        DexterAutomationRuntimeStateLog.log(state: .stopped, detail: "emergency_stop_active")
    }

    func beginRunningAutomation() {
        guard !isEmergencyStopActive else { return }
        runtimeState = .running
        DexterAutomationRuntimeStateLog.log(state: .running)
    }

    func markFailed(_ reason: String) {
        runtimeState = .failed
        DexterAutomationRuntimeStateLog.log(state: .failed, detail: reason)
    }

    func beginRecovery() {
        runtimeState = .recovering
        DexterAutomationRuntimeStateLog.log(state: .recovering)
    }

    func completeRecoveryToIdle() {
        runtimeState = .stopped
        DexterAutomationRuntimeStateLog.log(state: .stopped, detail: "recovered_idle")
    }

    /// User acknowledges emergency stop and re-enables Dexter (does not re-grant macOS TCC).
    func releaseEmergencyStopAfterUserAcknowledgement() {
        isEmergencyStopActive = false
        lastStopReason = nil
        runtimeState = .stopped
        DexterAutomationRuntimeStateLog.log(state: .stopped, detail: "emergency_stop_cleared")
    }
}
