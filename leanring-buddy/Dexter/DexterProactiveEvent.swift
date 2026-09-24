//
//  DexterProactiveEvent.swift
//  leanring-buddy
//
//  Proactive foundation: Event → Context → Policy → Agent → Action → Verification.
//  Dexter does not act autonomously unless the user explicitly enabled an automation.
//

import Foundation

enum DexterProactiveEventKind: String, Codable, Equatable, CaseIterable {
    case taskDeadlineApproaching = "TASK_DEADLINE_APPROACHING"
    case newFile = "NEW_FILE"
    case workflowRepetition = "WORKFLOW_REPETITION"
    case applicationState = "APPLICATION_STATE"
    case calendarEvent = "CALENDAR_EVENT"
}

enum DexterProactivePipelinePhase: String, Equatable, CaseIterable {
    case event = "EVENT"
    case context = "CONTEXT"
    case policy = "POLICY"
    case agent = "AGENT"
    case action = "ACTION"
    case verification = "VERIFICATION"
}

struct DexterProactiveEvent: Identifiable, Equatable, Codable {
    let id: UUID
    let kind: DexterProactiveEventKind
    let title: String
    let detail: String
    let detectedAt: Date
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        kind: DexterProactiveEventKind,
        title: String,
        detail: String,
        detectedAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.detectedAt = detectedAt
        self.metadata = metadata
    }
}

/// User-enabled automation with hard limits (required for any autonomous execution).
struct DexterProactiveAutomationLimits: Codable, Equatable {
    var maxDurationSeconds: TimeInterval
    var maxActionCount: Int
    var allowedPermissions: [String]
    var allowedApplicationBundleIdentifiers: [String]
    var stopConditions: [String]

    static let conservativeDefault = DexterProactiveAutomationLimits(
        maxDurationSeconds: 90,
        maxActionCount: 1,
        allowedPermissions: [],
        allowedApplicationBundleIdentifiers: [],
        stopConditions: ["permission_denied", "verification_failed", "budget_exceeded", "user_cancelled", "uncertainty"]
    )
}

struct DexterProactiveAutomationRegistration: Identifiable, Equatable, Codable {
    let id: UUID
    let eventKind: DexterProactiveEventKind
    /// Must be true for Policy to allow autonomous execution.
    var isExplicitlyEnabledByUser: Bool
    var limits: DexterProactiveAutomationLimits
    var linkedWorkflowIdentifier: String?

    init(
        id: UUID = UUID(),
        eventKind: DexterProactiveEventKind,
        isExplicitlyEnabledByUser: Bool = false,
        limits: DexterProactiveAutomationLimits = .conservativeDefault,
        linkedWorkflowIdentifier: String? = nil
    ) {
        self.id = id
        self.eventKind = eventKind
        self.isExplicitlyEnabledByUser = isExplicitlyEnabledByUser
        self.limits = limits
        self.linkedWorkflowIdentifier = linkedWorkflowIdentifier
    }
}

enum DexterProactiveResponseMode: String, Equatable {
    case detectAndExplain = "DETECT_EXPLAIN"
    case suggest = "SUGGEST"
    case askPermission = "ASK_PERMISSION"
    case executeAutonomously = "EXECUTE_AUTONOMOUS"
}

struct DexterProactivePolicyDecision: Equatable {
    let mode: DexterProactiveResponseMode
    let explanation: String
    let suggestion: String?
    let permissionPrompt: String?
    let stopOnUncertainty: Bool
    let mayInvokeAgentRuntime: Bool
}

struct DexterProactivePipelineOutcome: Equatable, Identifiable {
    let id: UUID
    let event: DexterProactiveEvent
    let policyDecision: DexterProactivePolicyDecision
    let proposedAction: DexterAction?
    let verificationSummary: String?
    let completedPhases: [DexterProactivePipelinePhase]

    init(
        id: UUID = UUID(),
        event: DexterProactiveEvent,
        policyDecision: DexterProactivePolicyDecision,
        proposedAction: DexterAction? = nil,
        verificationSummary: String? = nil,
        completedPhases: [DexterProactivePipelinePhase]
    ) {
        self.id = id
        self.event = event
        self.policyDecision = policyDecision
        self.proposedAction = proposedAction
        self.verificationSummary = verificationSummary
        self.completedPhases = completedPhases
    }
}
