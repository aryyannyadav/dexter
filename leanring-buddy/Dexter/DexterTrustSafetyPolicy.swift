//
//  DexterTrustSafetyPolicy.swift
//  leanring-buddy
//

import Foundation

/// Permission tiers — macOS TCC still applies; Dexter never bypasses system permissions.
enum DexterPermissionLevel: String, Codable, Equatable, CaseIterable {
    case observeOnly = "OBSERVE_ONLY"
    case readOnlyInspect = "READ_ONLY_INSPECT"
    case confirmEachAction = "CONFIRM_EACH_ACTION"
    case preApprovedLowRisk = "PRE_APPROVED_LOW_RISK"
    case explicitAutomationEnabled = "EXPLICIT_AUTOMATION_ENABLED"
}

struct DexterExecutionSafetyEnvelope: Equatable, Codable {
    var permissionLevel: DexterPermissionLevel
    var maxSteps: Int
    var maxToolCalls: Int
    var maxActions: Int
    var timeoutSeconds: TimeInterval
    var allowedApplicationBundleIdentifiers: [String]
    var allowedPermissions: [String]
    var stopConditions: [String]

    static let standard = DexterExecutionSafetyEnvelope(
        permissionLevel: .confirmEachAction,
        maxSteps: 12,
        maxToolCalls: 5,
        maxActions: 3,
        timeoutSeconds: 120,
        allowedApplicationBundleIdentifiers: [],
        allowedPermissions: [],
        stopConditions: [
            "permission_denied",
            "verification_failed",
            "budget_exceeded",
            "timeout",
            "emergency_stop",
            "user_cancelled",
            "uncertainty"
        ]
    )
}

enum DexterTrustSafetyPolicy {
    static func blocksExecution(
        permissionLevel: DexterPermissionLevel,
        isEmergencyStopActive: Bool,
        isComputerControlGloballyEnabled: Bool
    ) -> Bool {
        if isEmergencyStopActive {
            return true
        }
        if permissionLevel == .observeOnly {
            return true
        }
        if !isComputerControlGloballyEnabled && permissionLevel != .readOnlyInspect {
            return true
        }
        return false
    }

    static func isApplicationInScope(
        envelope: DexterExecutionSafetyEnvelope,
        targetApplicationBundleIdentifier: String?
    ) -> Bool {
        guard !envelope.allowedApplicationBundleIdentifiers.isEmpty else {
            return true
        }
        guard let targetApplicationBundleIdentifier else {
            return false
        }
        return envelope.allowedApplicationBundleIdentifiers.contains(targetApplicationBundleIdentifier)
    }

    static func isPermissionInScope(
        envelope: DexterExecutionSafetyEnvelope,
        requestedPermissions: [String]
    ) -> Bool {
        guard !envelope.allowedPermissions.isEmpty else {
            return true
        }
        let allowed = Set(envelope.allowedPermissions)
        return requestedPermissions.allSatisfy { allowed.contains($0) }
    }

    static func shouldStop(
        stopConditions: [String],
        triggeredCondition: String
    ) -> Bool {
        stopConditions.contains(triggeredCondition)
    }
}
