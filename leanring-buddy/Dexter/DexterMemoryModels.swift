//
//  DexterMemoryModels.swift
//  leanring-buddy
//

import Foundation

enum DexterMemoryType: String, Codable, CaseIterable, Equatable {
    case episodic = "EPISODIC"
    case semantic = "SEMANTIC"
    case project = "PROJECT"
    case workflow = "WORKFLOW"
    case preference = "PREFERENCE"
    case task = "TASK"
    case commitment = "COMMITMENT"
}

enum DexterMemorySource: String, Codable, Equatable {
    case explicitUserUtterance = "explicit_user_utterance"
    case inferredObservation = "inferred_observation"
    case workflowSystem = "workflow_system"
}

enum DexterMemoryStatus: String, Codable, Equatable {
    case active = "ACTIVE"
    case superseded = "SUPERSEDED"
    case expired = "EXPIRED"
    case forgotten = "FORGOTTEN"
}

struct DexterMemoryPermissions: Codable, Equatable {
    let mayIncludeInModelContext: Bool
    let mayShareWithWorkflow: Bool

    static let defaultForExplicitUser = DexterMemoryPermissions(
        mayIncludeInModelContext: true,
        mayShareWithWorkflow: true
    )

    static let inferredUntilConfirmed = DexterMemoryPermissions(
        mayIncludeInModelContext: false,
        mayShareWithWorkflow: false
    )
}

/// Canonical persisted memory object.
struct DexterStructuredMemoryRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let type: DexterMemoryType
    let content: String
    let source: DexterMemorySource
    let timestamp: Date
    let confidence: Double
    let importance: Double
    let project: String?
    let status: DexterMemoryStatus
    let expiration: Date?
    let supersedes: UUID?
    let permissions: DexterMemoryPermissions
    let title: String?

    init(
        id: UUID = UUID(),
        type: DexterMemoryType,
        content: String,
        source: DexterMemorySource,
        timestamp: Date = Date(),
        confidence: Double,
        importance: Double,
        project: String? = nil,
        status: DexterMemoryStatus = .active,
        expiration: Date? = nil,
        supersedes: UUID? = nil,
        permissions: DexterMemoryPermissions,
        title: String? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.source = source
        self.timestamp = timestamp
        self.confidence = confidence
        self.importance = importance
        self.project = project
        self.status = status
        self.expiration = expiration
        self.supersedes = supersedes
        self.permissions = permissions
        self.title = title
    }
}

// MARK: - Legacy entry surface (UI + older call sites)

enum DexterMemoryEntryKind: String, Codable, CaseIterable, Equatable {
    case userPreference
    case rememberedFact
}

enum DexterMemoryProvenance: String, Codable, Equatable {
    case explicitUserRequest
    case intentionalPreference
    case workflowRequired
}

struct DexterMemoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: DexterMemoryEntryKind
    let title: String
    let content: String
    let createdAt: Date
    let provenance: DexterMemoryProvenance

    init(
        id: UUID = UUID(),
        kind: DexterMemoryEntryKind,
        title: String,
        content: String,
        createdAt: Date = Date(),
        provenance: DexterMemoryProvenance
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.provenance = provenance
    }
}

extension DexterStructuredMemoryRecord {
    func legacyMemoryEntry() -> DexterMemoryEntry {
        let kind: DexterMemoryEntryKind = type == .preference ? .userPreference : .rememberedFact

        let provenance: DexterMemoryProvenance
        switch source {
        case .explicitUserUtterance:
            provenance = kind == .userPreference ? .intentionalPreference : .explicitUserRequest
        case .workflowSystem:
            provenance = .workflowRequired
        case .inferredObservation:
            provenance = .explicitUserRequest
        }

        return DexterMemoryEntry(
            id: id,
            kind: kind,
            title: title ?? String(content.prefix(48)),
            content: content,
            createdAt: timestamp,
            provenance: provenance
        )
    }

    static func explicitSemantic(
        content: String,
        title: String?,
        project: String? = nil,
        type: DexterMemoryType = .semantic
    ) -> DexterStructuredMemoryRecord {
        DexterStructuredMemoryRecord(
            type: type,
            content: content,
            source: .explicitUserUtterance,
            confidence: 0.95,
            importance: 0.85,
            project: project,
            permissions: .defaultForExplicitUser,
            title: title
        )
    }

    static func explicitPreference(content: String, title: String) -> DexterStructuredMemoryRecord {
        DexterStructuredMemoryRecord(
            type: .preference,
            content: content,
            source: .explicitUserUtterance,
            confidence: 0.95,
            importance: 0.9,
            permissions: .defaultForExplicitUser,
            title: title
        )
    }
}

struct DexterWorkflowContextState: Codable, Equatable {
    var summary: String
    var updatedAt: Date

    init(summary: String, updatedAt: Date = Date()) {
        self.summary = summary
        self.updatedAt = updatedAt
    }
}

struct DexterMemoryInferenceSuggestion: Equatable, Identifiable {
    let id: UUID
    let suggestedContent: String
    let suggestedType: DexterMemoryType
    let observationCount: Int
}

enum DexterMemoryIntentOutcome: Equatable {
    case noMemoryIntent
    case appliedSilently
    case userFacingResponse(String)
    case inferenceConfirmationPrompt(String)
}

enum DexterMemoryError: Error, Equatable {
    case storageRejected(String)

    var userFacingMessage: String {
        switch self {
        case .storageRejected(let message):
            return message
        }
    }
}
