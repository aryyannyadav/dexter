//
//  DexterProactiveEventDetector.swift
//  leanring-buddy
//

import Foundation

/// Authorized inputs for proactive detection (no fabricated calendar/file events).
struct DexterProactiveDetectionInput: Equatable {
    let accountabilitySnapshot: DexterAccountabilityTaskSnapshot
    let activeApplicationName: String?
    let activeApplicationBundleIdentifier: String?
    let previousApplicationBundleIdentifier: String?
    let newlyObservedApprovedFilePaths: [String]
    let repeatedWorkflowIdentifier: String?
    let repeatedWorkflowCount: Int
    let calendarEventTitle: String?
    let calendarEventStartsAt: Date?
    let referenceDate: Date

    init(
        accountabilitySnapshot: DexterAccountabilityTaskSnapshot,
        activeApplicationName: String? = nil,
        activeApplicationBundleIdentifier: String? = nil,
        previousApplicationBundleIdentifier: String? = nil,
        newlyObservedApprovedFilePaths: [String] = [],
        repeatedWorkflowIdentifier: String? = nil,
        repeatedWorkflowCount: Int = 0,
        calendarEventTitle: String? = nil,
        calendarEventStartsAt: Date? = nil,
        referenceDate: Date = Date()
    ) {
        self.accountabilitySnapshot = accountabilitySnapshot
        self.activeApplicationName = activeApplicationName
        self.activeApplicationBundleIdentifier = activeApplicationBundleIdentifier
        self.previousApplicationBundleIdentifier = previousApplicationBundleIdentifier
        self.newlyObservedApprovedFilePaths = newlyObservedApprovedFilePaths
        self.repeatedWorkflowIdentifier = repeatedWorkflowIdentifier
        self.repeatedWorkflowCount = repeatedWorkflowCount
        self.calendarEventTitle = calendarEventTitle
        self.calendarEventStartsAt = calendarEventStartsAt
        self.referenceDate = referenceDate
    }
}

enum DexterProactiveEventDetector {
    static let defaultDeadlineHorizonSeconds: TimeInterval = 24 * 60 * 60
    static let workflowRepetitionThreshold = 3

    static func detectEvents(from input: DexterProactiveDetectionInput) -> [DexterProactiveEvent] {
        var events: [DexterProactiveEvent] = []

        events.append(contentsOf: detectTaskDeadlineEvents(from: input))
        events.append(contentsOf: detectNewFileEvents(from: input))
        events.append(contentsOf: detectWorkflowRepetitionEvents(from: input))
        if let applicationEvent = detectApplicationStateEvent(from: input) {
            events.append(applicationEvent)
        }
        if let calendarEvent = detectCalendarEvent(from: input) {
            events.append(calendarEvent)
        }

        return events
    }

    private static func detectTaskDeadlineEvents(from input: DexterProactiveDetectionInput) -> [DexterProactiveEvent] {
        let horizonEnd = input.referenceDate.addingTimeInterval(defaultDeadlineHorizonSeconds)
        return input.accountabilitySnapshot.openTasks.compactMap { task in
            guard let deadline = task.deadline else { return nil }
            guard deadline >= input.referenceDate && deadline <= horizonEnd else { return nil }
            return DexterProactiveEvent(
                kind: .taskDeadlineApproaching,
                title: task.title,
                detail: "Deadline is approaching for stored task “\(task.title)”.",
                metadata: [
                    "task_id": task.id.uuidString,
                    "deadline": ISO8601DateFormatter().string(from: deadline)
                ]
            )
        }
    }

    private static func detectNewFileEvents(from input: DexterProactiveDetectionInput) -> [DexterProactiveEvent] {
        input.newlyObservedApprovedFilePaths.map { path in
            DexterProactiveEvent(
                kind: .newFile,
                title: (path as NSString).lastPathComponent,
                detail: "New file observed in an approved folder: \(path).",
                metadata: ["path": path]
            )
        }
    }

    private static func detectWorkflowRepetitionEvents(from input: DexterProactiveDetectionInput) -> [DexterProactiveEvent] {
        guard let workflowIdentifier = input.repeatedWorkflowIdentifier,
              input.repeatedWorkflowCount >= workflowRepetitionThreshold else {
            return []
        }

        return [
            DexterProactiveEvent(
                kind: .workflowRepetition,
                title: workflowIdentifier,
                detail: "Workflow “\(workflowIdentifier)” repeated \(input.repeatedWorkflowCount) times in session telemetry.",
                metadata: [
                    "workflow_identifier": workflowIdentifier,
                    "count": String(input.repeatedWorkflowCount)
                ]
            )
        ]
    }

    private static func detectApplicationStateEvent(from input: DexterProactiveDetectionInput) -> DexterProactiveEvent? {
        guard let currentBundle = input.activeApplicationBundleIdentifier?.nonEmptyTrimmedValue,
              let previousBundle = input.previousApplicationBundleIdentifier?.nonEmptyTrimmedValue,
              currentBundle != previousBundle else {
            return nil
        }

        let applicationName = input.activeApplicationName ?? currentBundle
        return DexterProactiveEvent(
            kind: .applicationState,
            title: applicationName,
            detail: "Active application changed to \(applicationName).",
            metadata: [
                "bundle_identifier": currentBundle,
                "previous_bundle_identifier": previousBundle
            ]
        )
    }

    private static func detectCalendarEvent(from input: DexterProactiveDetectionInput) -> DexterProactiveEvent? {
        guard let title = input.calendarEventTitle?.nonEmptyTrimmedValue,
              let startsAt = input.calendarEventStartsAt else {
            return nil
        }

        let horizonEnd = input.referenceDate.addingTimeInterval(defaultDeadlineHorizonSeconds)
        guard startsAt >= input.referenceDate && startsAt <= horizonEnd else {
            return nil
        }

        return DexterProactiveEvent(
            kind: .calendarEvent,
            title: title,
            detail: "Calendar event “\(title)” is scheduled soon.",
            metadata: ["starts_at": ISO8601DateFormatter().string(from: startsAt)]
        )
    }
}
