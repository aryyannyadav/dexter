//
//  DexterFileWorkspaceModels.swift
//  leanring-buddy
//
//  Per-Dexter user-selected folders/files (product "Dexter Workspace").
//  Not to be confused with DexterWorkspaceSnapshot (semantic app state restore).
//

import Foundation

enum DexterFileWorkspaceLocationKind: String, Codable, Equatable {
    case folder
    case file
}

enum DexterFileWorkspaceAccessState: String, Codable, Equatable {
    case available
    case permissionRequired
    case missing
    case stale
    case unavailable
}

enum DexterFileWorkspaceIndexStatus: String, Codable, Equatable {
    case notIndexed
    case indexing
    case ready
    case needsRefresh
    case error
}

enum DexterFileIndexStatus: String, Codable, Equatable {
    case metadataOnly
    case indexed
    case skippedUnsupported
    case error
}

enum DexterFileWorkspaceContentKind: String, Codable, Equatable {
    case text
    case markdown
    case pdf
    case image
    case sourceCode
    case json
    case csv
    case document
    case other

    var userFacingLabel: String {
        switch self {
        case .text: return "Text"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        case .image: return "Image"
        case .sourceCode: return "Source code"
        case .json: return "JSON"
        case .csv: return "CSV"
        case .document: return "Document"
        case .other: return "File"
        }
    }
}

struct DexterFileWorkspaceLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: DexterFileWorkspaceLocationKind
    var displayName: String
    var securityScopedBookmarkData: Data?
    var lastResolvedPath: String?
    var accessState: DexterFileWorkspaceAccessState
    let addedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: DexterFileWorkspaceLocationKind,
        displayName: String,
        securityScopedBookmarkData: Data? = nil,
        lastResolvedPath: String? = nil,
        accessState: DexterFileWorkspaceAccessState = .permissionRequired,
        addedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.lastResolvedPath = lastResolvedPath
        self.accessState = accessState
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}

struct DexterFileWorkspaceGitSummary: Codable, Equatable {
    var isGitRepository: Bool
    var branchName: String?
    var shortStatusSummary: String?
}

/// User-selected collection of folders/files for one Dexter profile.
struct DexterFileWorkspace: Identifiable, Codable, Equatable {
    let id: UUID
    var dexterProfileId: UUID
    var name: String
    var locations: [DexterFileWorkspaceLocation]
    var indexStatus: DexterFileWorkspaceIndexStatus
    var indexProgress: Double?
    var lastIndexedAt: Date?
    var indexedFolderCount: Int?
    var indexedFileCount: Int?
    var gitSummary: DexterFileWorkspaceGitSummary?
    var lastIndexErrorMessage: String?
    let createdAt: Date
    var updatedAt: Date

    var hasAnyLocation: Bool {
        !locations.isEmpty
    }

    init(
        id: UUID = UUID(),
        dexterProfileId: UUID,
        name: String,
        locations: [DexterFileWorkspaceLocation] = [],
        indexStatus: DexterFileWorkspaceIndexStatus = .notIndexed,
        indexProgress: Double? = nil,
        lastIndexedAt: Date? = nil,
        indexedFolderCount: Int? = nil,
        indexedFileCount: Int? = nil,
        gitSummary: DexterFileWorkspaceGitSummary? = nil,
        lastIndexErrorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dexterProfileId = dexterProfileId
        self.name = name
        self.locations = locations
        self.indexStatus = indexStatus
        self.indexProgress = indexProgress
        self.lastIndexedAt = lastIndexedAt
        self.indexedFolderCount = indexedFolderCount
        self.indexedFileCount = indexedFileCount
        self.gitSummary = gitSummary
        self.lastIndexErrorMessage = lastIndexErrorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Lightweight file metadata for workspace search and model context (no full file bodies in profile).
struct DexterFileContext: Identifiable, Codable, Equatable {
    var fileID: String
    var workspaceID: UUID
    var locationID: UUID
    var name: String
    var absolutePath: String
    var displayPath: String
    var contentKind: DexterFileWorkspaceContentKind
    var byteSize: Int64?
    var modifiedAt: Date?
    var indexStatus: DexterFileIndexStatus
    var searchableTextSnippet: String?
    var metadata: [String: String]

    var id: String { fileID }
}

struct DexterFileWorkspaceIndexSnapshot: Codable, Equatable {
    var workspaceId: UUID
    var files: [DexterFileContext]
    var updatedAt: Date
}

/// Injected into DexterContext for bounded workspace-aware turns.
struct DexterFileWorkspaceContextSlice: Equatable {
    var workspaceId: UUID
    var workspaceName: String
    var indexStatus: DexterFileWorkspaceIndexStatus
    var summaryLines: [String]
    var relevantFiles: [DexterFileContext]
    var matchedEditorFileName: String?
}
