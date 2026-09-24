//
//  DexterAccountabilityTask.swift
//  leanring-buddy
//
//  Structured user tasks (distinct from template-driven `DexterTask` workflows).
//

import Foundation

enum DexterAccountabilityTaskStatus: String, Codable, Equatable, CaseIterable {
    case notStarted = "NOT_STARTED"
    case inProgress = "IN_PROGRESS"
    case blocked = "BLOCKED"
    case completed = "COMPLETED"
    case cancelled = "CANCELLED"
}

enum DexterAccountabilityTaskPriority: String, Codable, Equatable, CaseIterable {
    case low = "LOW"
    case normal = "NORMAL"
    case high = "HIGH"
}

enum DexterAccountabilityTaskSource: String, Codable, Equatable {
    case explicitUserUtterance = "explicit_user_utterance"
    case workflowSystem = "workflow_system"
    case reminder = "reminder"
}

struct DexterAccountabilityTaskStep: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct DexterAccountabilityCommitment: Codable, Equatable {
    let summary: String
    let committedAt: Date
    var remindAt: Date?
    var linkedMemoryIdentifier: UUID?
}

struct DexterAccountabilityVerification: Codable, Equatable {
    let strategy: String
    var expectedOutcome: String?
    var lastVerifiedAt: Date?
}

struct DexterAccountabilityTask: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String?
    var project: String?
    var goal: String?
    var status: DexterAccountabilityTaskStatus
    var priority: DexterAccountabilityTaskPriority
    var deadline: Date?
    let createdAt: Date
    var updatedAt: Date
    var source: DexterAccountabilityTaskSource
    var steps: [DexterAccountabilityTaskStep]
    var commitment: DexterAccountabilityCommitment?
    var verification: DexterAccountabilityVerification?

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        project: String? = nil,
        goal: String? = nil,
        status: DexterAccountabilityTaskStatus = .notStarted,
        priority: DexterAccountabilityTaskPriority = .normal,
        deadline: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: DexterAccountabilityTaskSource = .explicitUserUtterance,
        steps: [DexterAccountabilityTaskStep] = [],
        commitment: DexterAccountabilityCommitment? = nil,
        verification: DexterAccountabilityVerification? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.project = project
        self.goal = goal
        self.status = status
        self.priority = priority
        self.deadline = deadline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.steps = steps
        self.commitment = commitment
        self.verification = verification
    }

    var isOpen: Bool {
        status == .notStarted || status == .inProgress || status == .blocked
    }

    var nextIncompleteStep: DexterAccountabilityTaskStep? {
        steps.first { !$0.isCompleted }
    }
}

struct DexterAccountabilityTaskSnapshot: Equatable {
    let activeTask: DexterAccountabilityTask?
    let openTasks: [DexterAccountabilityTask]
    let unfinishedTasks: [DexterAccountabilityTask]
    let pendingReminders: [DexterAccountabilityTask]

    static let empty = DexterAccountabilityTaskSnapshot(
        activeTask: nil,
        openTasks: [],
        unfinishedTasks: [],
        pendingReminders: []
    )
}
