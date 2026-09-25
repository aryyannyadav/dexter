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
    case userConfirmed = "user_confirmed"
    case inferredObservation = "inferred_observation"
    case workflowSystem = "workflow_system"
    case conversation = "conversation"
    case workspace = "workspace"
    case routineContext = "routine_context"
}

/// Where a memory applies (not a permission grant).
enum DexterMemoryScope: String, Codable, Equatable {
    case global
    case dexterProfile
    case workspace
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
    let updatedAt: Date
    let confidence: Double
    let importance: Double
    let project: String?
    let status: DexterMemoryStatus
    let expiration: Date?
    let supersedes: UUID?
    let permissions: DexterMemoryPermissions
    let title: String?
    let scope: DexterMemoryScope
    let dexterProfileId: UUID?
    let fileWorkspaceId: UUID?

    init(
        id: UUID = UUID(),
        type: DexterMemoryType,
        content: String,
        source: DexterMemorySource,
        timestamp: Date = Date(),
        updatedAt: Date? = nil,
        confidence: Double,
        importance: Double,
        project: String? = nil,
        status: DexterMemoryStatus = .active,
        expiration: Date? = nil,
        supersedes: UUID? = nil,
        permissions: DexterMemoryPermissions,
        title: String? = nil,
        scope: DexterMemoryScope = .global,
        dexterProfileId: UUID? = nil,
        fileWorkspaceId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.source = source
        self.timestamp = timestamp
        self.updatedAt = updatedAt ?? timestamp
        self.confidence = confidence
        self.importance = importance
        self.project = project
        self.status = status
        self.expiration = expiration
        self.supersedes = supersedes
        self.permissions = permissions
        self.title = title
        self.scope = scope
        self.dexterProfileId = dexterProfileId
        self.fileWorkspaceId = fileWorkspaceId
    }

    enum CodingKeys: String, CodingKey {
        case id, type, content, source, timestamp, updatedAt, confidence, importance, project
        case status, expiration, supersedes, permissions, title, scope, dexterProfileId, fileWorkspaceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(DexterMemoryType.self, forKey: .type)
        content = try container.decode(String.self, forKey: .content)
        source = try container.decode(DexterMemorySource.self, forKey: .source)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? timestamp
        confidence = try container.decode(Double.self, forKey: .confidence)
        importance = try container.decode(Double.self, forKey: .importance)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        status = try container.decode(DexterMemoryStatus.self, forKey: .status)
        expiration = try container.decodeIfPresent(Date.self, forKey: .expiration)
        supersedes = try container.decodeIfPresent(UUID.self, forKey: .supersedes)
        permissions = try container.decode(DexterMemoryPermissions.self, forKey: .permissions)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        scope = try container.decodeIfPresent(DexterMemoryScope.self, forKey: .scope) ?? .global
        dexterProfileId = try container.decodeIfPresent(UUID.self, forKey: .dexterProfileId)
        fileWorkspaceId = try container.decodeIfPresent(UUID.self, forKey: .fileWorkspaceId)
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
        case .inferredObservation, .conversation, .workspace, .routineContext:
            provenance = .explicitUserRequest
        case .userConfirmed:
            provenance = .intentionalPreference
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
        type: DexterMemoryType = .semantic,
        binding: DexterMemoryBinding = .global
    ) -> DexterStructuredMemoryRecord {
        DexterStructuredMemoryRecord(
            type: type,
            content: content,
            source: .explicitUserUtterance,
            confidence: 0.95,
            importance: 0.85,
            project: project,
            permissions: .defaultForExplicitUser,
            title: title,
            scope: binding.scope,
            dexterProfileId: binding.dexterProfileId,
            fileWorkspaceId: binding.fileWorkspaceId
        )
    }

    static func explicitPreference(
        content: String,
        title: String,
        binding: DexterMemoryBinding = .global
    ) -> DexterStructuredMemoryRecord {
        DexterStructuredMemoryRecord(
            type: .preference,
            content: content,
            source: .explicitUserUtterance,
            confidence: 0.95,
            importance: 0.9,
            permissions: .defaultForExplicitUser,
            title: title,
            scope: binding.scope,
            dexterProfileId: binding.dexterProfileId,
            fileWorkspaceId: binding.fileWorkspaceId
        )
    }
}

/// Associates new memories with the active Dexter and optional workspace.
struct DexterMemoryBinding: Equatable {
    let scope: DexterMemoryScope
    let dexterProfileId: UUID?
    let fileWorkspaceId: UUID?

    static let global = DexterMemoryBinding(scope: .global, dexterProfileId: nil, fileWorkspaceId: nil)

    static func forDexterProfile(_ profileId: UUID) -> DexterMemoryBinding {
        DexterMemoryBinding(scope: .dexterProfile, dexterProfileId: profileId, fileWorkspaceId: nil)
    }

    static func forWorkspace(profileId: UUID, fileWorkspaceId: UUID) -> DexterMemoryBinding {
        DexterMemoryBinding(scope: .workspace, dexterProfileId: profileId, fileWorkspaceId: fileWorkspaceId)
    }
}

struct DexterMemoryRetrievalContext: Equatable {
    let activeDexterProfileId: UUID?
    let activeFileWorkspaceId: UUID?
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
