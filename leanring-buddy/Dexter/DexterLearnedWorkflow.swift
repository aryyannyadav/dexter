//
//  DexterLearnedWorkflow.swift
//  leanring-buddy
//

import Foundation

/// Runtime phases for reusable workflows (maps onto the existing action pipeline).
enum DexterWorkflowRuntimePhase: String, Codable, Equatable, CaseIterable {
    case trigger = "TRIGGER"
    case condition = "CONDITION"
    case context = "CONTEXT"
    case plan = "PLAN"
    case permission = "PERMISSION"
    case action = "ACTION"
    case verify = "VERIFY"
    case nextStep = "NEXT_STEP"
    case waitingForUser = "WAITING_FOR_USER"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
}

struct DexterWorkflowCondition: Codable, Equatable {
    let kind: String
    let parameter: String?
}

struct DexterWorkflowContextRequirements: Codable, Equatable {
    let requiresAccessibilityPermission: Bool
    let requiresApplicationLifecycleProbe: Bool
    let requiresBrowserState: Bool
    let requiredContextSections: [String]
}

struct DexterWorkflowStepVerification: Codable, Equatable {
    let strategy: String
    let expectedValue: String?
}

/// Semantic step kinds — never store screen coordinates; each run rediscovers context.
enum DexterWorkflowStepActionKind: String, Codable, Equatable {
    case openApplication
    case openBrowser
    case browserNavigate
    case runTerminalInspect
    case waitForUserConfirmation
    case askUserWhenUncertain
}

struct DexterWorkflowStepDefinition: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let instruction: String
    let actionKind: DexterWorkflowStepActionKind
    let parameters: [String: String]
    let verification: DexterWorkflowStepVerification?
    let contextRequirements: DexterWorkflowContextRequirements
    let requiredPermissions: [String]
}

struct DexterLearnedWorkflow: Codable, Identifiable, Equatable {
    let id: UUID
    let workflowIdentifier: String
    let name: String
    let triggerPhrases: [String]
    let conditions: [DexterWorkflowCondition]
    let contextRequirements: DexterWorkflowContextRequirements
    let steps: [DexterWorkflowStepDefinition]
    let permissions: [String]
    let verificationPolicy: String
    let owner: String
    let createdAt: Date
    var updatedAt: Date
}

struct DexterWorkflowRunSession: Codable, Identifiable, Equatable {
    let id: UUID
    let workflowIdentifier: String
    let workflowName: String
    var currentStepIndex: Int
    var runtimePhase: DexterWorkflowRuntimePhase
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        workflowIdentifier: String,
        workflowName: String,
        currentStepIndex: Int = 0,
        runtimePhase: DexterWorkflowRuntimePhase = .trigger,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.workflowIdentifier = workflowIdentifier
        self.workflowName = workflowName
        self.currentStepIndex = currentStepIndex
        self.runtimePhase = runtimePhase
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isTerminal: Bool {
        runtimePhase == .completed || runtimePhase == .failed || runtimePhase == .cancelled
    }

    var progressLabel: String {
        "step \(currentStepIndex + 1)"
    }
}

struct DexterWorkflowTurnOutcome: Equatable {
    let session: DexterWorkflowRunSession
    let spokenSummary: String
    let didHandleTurn: Bool
    let requiresFreshContextOnNextTurn: Bool
}

/// Placeholder for future recording from observed user actions (not implemented in this build).
enum DexterWorkflowRecordingEngine {
    static let isRecordingFromObservedActionsEnabled = false
}
