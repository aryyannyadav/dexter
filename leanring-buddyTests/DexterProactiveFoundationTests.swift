//
//  DexterProactiveFoundationTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterProactiveFoundationTests {
    @Test func defaultAutomationsAreDisabled() {
        let registrations = DexterProactiveAutomationRegistry.defaultRegistrations()
        #expect(registrations.allSatisfy { !$0.isExplicitlyEnabledByUser })
        #expect(registrations.count == DexterProactiveEventKind.allCases.count)
    }

    @Test func detectorFindsApproachingDeadlineFromStoredTask() {
        let deadline = Date().addingTimeInterval(60 * 60)
        let snapshot = DexterAccountabilityTaskSnapshot(
            activeTask: DexterAccountabilityTask(title: "Report", deadline: deadline, status: .inProgress),
            openTasks: [],
            unfinishedTasks: [],
            pendingReminders: []
        )

        let events = DexterProactiveEventDetector.detectEvents(
            from: DexterProactiveDetectionInput(
                accountabilitySnapshot: snapshot,
                referenceDate: Date()
            )
        )

        #expect(events.contains { $0.kind == .taskDeadlineApproaching })
    }

    @Test func policyDefaultsToSuggestWithoutAutomation() {
        let event = DexterProactiveEvent(
            kind: .newFile,
            title: "notes.md",
            detail: "New file in Downloads."
        )
        let decision = DexterProactivePolicyEngine.evaluate(
            event: event,
            automationRegistration: DexterProactiveAutomationRegistration(eventKind: .newFile),
            isGlobalComputerControlAvailable: true,
            userGrantedProactiveExecution: false
        )

        #expect(decision.mode == .suggest)
        #expect(decision.mayInvokeAgentRuntime == false)
    }

    @Test func policyRequiresGrantEvenWhenAutomationEnabled() {
        let event = DexterProactiveEvent(
            kind: .workflowRepetition,
            title: "prepare_coding_environment_v1",
            detail: "Repeated workflow."
        )
        var registration = DexterProactiveAutomationRegistration(eventKind: .workflowRepetition)
        registration.isExplicitlyEnabledByUser = true

        let decision = DexterProactivePolicyEngine.evaluate(
            event: event,
            automationRegistration: registration,
            isGlobalComputerControlAvailable: true,
            userGrantedProactiveExecution: false
        )

        #expect(decision.mode == .askPermission)
    }

    @Test func pipelineDoesNotExecuteWhenAutomationDisabled() async {
        let event = DexterProactiveEvent(
            kind: .applicationState,
            title: "Safari",
            detail: "App changed.",
            metadata: ["bundle_identifier": "com.apple.Safari"]
        )

        let outcome = await DexterProactiveFoundationEngine.processEvent(
            event: event,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "proactive")),
            automationRegistrations: DexterProactiveAutomationRegistry.defaultRegistrations(),
            userGrantedProactiveExecution: false,
            executeVerifiedAction: { _ in
                Issue.record("Should not execute without explicit automation.")
                fatalError()
            }
        )

        #expect(outcome.policyDecision.mode == .suggest)
        #expect(!outcome.completedPhases.contains(.action))
    }

    @Test func limitsBlockExcessiveActions() {
        let limits = DexterProactiveAutomationLimits(
            maxDurationSeconds: 30,
            maxActionCount: 1,
            allowedPermissions: ["filesystem"],
            allowedApplicationBundleIdentifiers: [],
            stopConditions: ["uncertainty"]
        )

        #expect(
            DexterProactivePolicyEngine.isWithinLimits(
                limits: limits,
                elapsedSeconds: 5,
                actionCount: 1,
                requestedPermissions: ["filesystem"],
                targetApplicationBundleIdentifier: nil
            )
        )
        #expect(
            !DexterProactivePolicyEngine.isWithinLimits(
                limits: limits,
                elapsedSeconds: 5,
                actionCount: 2,
                requestedPermissions: ["filesystem"],
                targetApplicationBundleIdentifier: nil
            )
        )
    }

    @Test func calendarEventRequiresAuthorizedPayload() {
        let withoutCalendar = DexterProactiveEventDetector.detectEvents(
            from: DexterProactiveDetectionInput(accountabilitySnapshot: .empty)
        )
        #expect(!withoutCalendar.contains { $0.kind == .calendarEvent })

        let withCalendar = DexterProactiveEventDetector.detectEvents(
            from: DexterProactiveDetectionInput(
                accountabilitySnapshot: .empty,
                calendarEventTitle: "Team sync",
                calendarEventStartsAt: Date().addingTimeInterval(600)
            )
        )
        #expect(withCalendar.contains { $0.kind == .calendarEvent })
    }
}
