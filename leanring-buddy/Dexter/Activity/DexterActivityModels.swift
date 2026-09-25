//
//  DexterActivityModels.swift
//  leanring-buddy
//

import Foundation

enum DexterActivityKind: String, Codable, Equatable, CaseIterable {
    case conversation
    case action
    case routine
    case memory
    case workspace
    case suggestion
}

enum DexterActivityStatus: String, Codable, Equatable {
    case completed
    case verified
    case partiallyVerified
    case failed
    case needsPermission
    case cancelled
    case timedOut
    case running
}

enum DexterActivitySource: String, Codable, Equatable {
    case actionPipeline
    case routineRunner
    case memoryStore
    case workspaceService
    case conversationService
    case suggestionService
}

struct DexterActivityDetail: Codable, Equatable {
    var requestedUtterance: String?
    var actionLabel: String?
    var resultSummary: String?
    var verificationSummary: String?
    var workspaceDisplayPath: String?
    var memoryContentPreview: String?
    var routineName: String?
    var suggestionTitle: String?
}

struct DexterActivityRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let dexterProfileId: UUID?
    let kind: DexterActivityKind
    let title: String
    let summary: String?
    let status: DexterActivityStatus
    let timestamp: Date
    let source: DexterActivitySource
    let relatedConversationId: UUID?
    let relatedRoutineId: UUID?
    let relatedWorkspaceId: UUID?
    let relatedActionId: UUID?
    let relatedMemoryId: UUID?
    let detail: DexterActivityDetail?

    init(
        id: UUID = UUID(),
        dexterProfileId: UUID?,
        kind: DexterActivityKind,
        title: String,
        summary: String? = nil,
        status: DexterActivityStatus,
        timestamp: Date = Date(),
        source: DexterActivitySource,
        relatedConversationId: UUID? = nil,
        relatedRoutineId: UUID? = nil,
        relatedWorkspaceId: UUID? = nil,
        relatedActionId: UUID? = nil,
        relatedMemoryId: UUID? = nil,
        detail: DexterActivityDetail? = nil
    ) {
        self.id = id
        self.dexterProfileId = dexterProfileId
        self.kind = kind
        self.title = title
        self.summary = summary
        self.status = status
        self.timestamp = timestamp
        self.source = source
        self.relatedConversationId = relatedConversationId
        self.relatedRoutineId = relatedRoutineId
        self.relatedWorkspaceId = relatedWorkspaceId
        self.relatedActionId = relatedActionId
        self.relatedMemoryId = relatedMemoryId
        self.detail = detail
    }
}

struct DexterActivityLinkage: Equatable {
    let dexterProfileId: UUID?
    let conversationId: UUID?
    let fileWorkspaceId: UUID?
}

enum DexterActivityFilter: String, CaseIterable, Identifiable {
    case all
    case actions
    case routines
    case memory
    case workspace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .actions: return "Actions"
        case .routines: return "Routines"
        case .memory: return "Memory"
        case .workspace: return "Workspace"
        }
    }

    func matches(_ record: DexterActivityRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .actions:
            return record.kind == .action
        case .routines:
            return record.kind == .routine
        case .memory:
            return record.kind == .memory
        case .workspace:
            return record.kind == .workspace
        }
    }
}
