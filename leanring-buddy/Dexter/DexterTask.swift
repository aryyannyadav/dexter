//
//  DexterTask.swift
//  leanring-buddy
//

import Foundation

/// Lifecycle state for a guided multi-step Dexter workflow.
enum TaskState: String, Codable, Equatable, CaseIterable {
    case planning
    case waitingForUser = "waiting_for_user"
    case waitingForPermission = "waiting_for_permission"
    case executing
    case verifying
    case completed
    case failed
    case cancelled
}

enum TaskStepKind: String, Codable, Equatable {
    case inspectAssignmentOnScreen
    case openBrowserForSubmission
    case inspectRequiredFields
    case prepareUploadGuidance
    case requestSubmissionPermission
    case guideFinalSubmission
    case verifySubmission
    case reportCompletion
}

/// One step in a bounded Dexter workflow. Steps are predefined — Dexter does not invent new steps at runtime.
struct TaskStep: Identifiable, Equatable, Codable {
    let id: UUID
    let kind: TaskStepKind
    let title: String
    let instruction: String
    var state: TaskState

    init(
        id: UUID = UUID(),
        kind: TaskStepKind,
        title: String,
        instruction: String,
        state: TaskState = .planning
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.instruction = instruction
        self.state = state
    }
}

/// A bounded, template-driven workflow (not a general autonomous agent plan).
struct DexterTask: Identifiable, Equatable, Codable {
    let id: UUID
    let workflowIdentifier: String
    let title: String
    let userGoalDescription: String
    var steps: [TaskStep]
    var currentStepIndex: Int
    var state: TaskState
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workflowIdentifier: String,
        title: String,
        userGoalDescription: String,
        steps: [TaskStep],
        currentStepIndex: Int = 0,
        state: TaskState = .planning,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workflowIdentifier = workflowIdentifier
        self.title = title
        self.userGoalDescription = userGoalDescription
        self.steps = steps
        self.currentStepIndex = currentStepIndex
        self.state = state
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var currentStep: TaskStep? {
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var isTerminal: Bool {
        state == .completed || state == .failed || state == .cancelled
    }

    var progressLabel: String {
        guard !steps.isEmpty else { return "0/0" }
        let completedCount = steps.prefix(currentStepIndex).count
        return "\(min(completedCount + 1, steps.count))/\(steps.count)"
    }
}
