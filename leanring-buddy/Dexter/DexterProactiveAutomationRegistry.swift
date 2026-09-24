//
//  DexterProactiveAutomationRegistry.swift
//  leanring-buddy
//

import Foundation

enum DexterProactiveAutomationRegistry {
    static func defaultRegistrations() -> [DexterProactiveAutomationRegistration] {
        DexterProactiveEventKind.allCases.map { eventKind in
            DexterProactiveAutomationRegistration(
                eventKind: eventKind,
                isExplicitlyEnabledByUser: false,
                limits: defaultLimits(for: eventKind)
            )
        }
    }

    static func registration(
        for eventKind: DexterProactiveEventKind,
        in registrations: [DexterProactiveAutomationRegistration]
    ) -> DexterProactiveAutomationRegistration? {
        registrations.first { $0.eventKind == eventKind }
    }

    private static func defaultLimits(for eventKind: DexterProactiveEventKind) -> DexterProactiveAutomationLimits {
        switch eventKind {
        case .taskDeadlineApproaching:
            return DexterProactiveAutomationLimits(
                maxDurationSeconds: 120,
                maxActionCount: 2,
                allowedPermissions: [],
                allowedApplicationBundleIdentifiers: [],
                stopConditions: ["deadline_passed", "user_acknowledged", "uncertainty"]
            )
        case .newFile:
            return DexterProactiveAutomationLimits(
                maxDurationSeconds: 90,
                maxActionCount: 2,
                allowedPermissions: ["filesystem"],
                allowedApplicationBundleIdentifiers: [],
                stopConditions: ["path_not_approved", "verification_failed", "uncertainty"]
            )
        case .workflowRepetition:
            return DexterProactiveAutomationLimits(
                maxDurationSeconds: 180,
                maxActionCount: 4,
                allowedPermissions: ["accessibility"],
                allowedApplicationBundleIdentifiers: [],
                stopConditions: ["workflow_completed", "permission_denied", "uncertainty"]
            )
        case .applicationState:
            return DexterProactiveAutomationLimits(
                maxDurationSeconds: 60,
                maxActionCount: 1,
                allowedPermissions: ["accessibility"],
                allowedApplicationBundleIdentifiers: [],
                stopConditions: ["application_changed", "uncertainty"]
            )
        case .calendarEvent:
            return DexterProactiveAutomationLimits(
                maxDurationSeconds: 120,
                maxActionCount: 1,
                allowedPermissions: [],
                allowedApplicationBundleIdentifiers: [],
                stopConditions: ["event_started", "user_dismissed", "uncertainty"]
            )
        }
    }
}
