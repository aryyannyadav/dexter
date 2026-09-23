//
//  DexterMemoryModels.swift
//  leanring-buddy
//

import Foundation

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

struct DexterWorkflowContextState: Codable, Equatable {
    var summary: String
    var updatedAt: Date

    init(summary: String, updatedAt: Date = Date()) {
        self.summary = summary
        self.updatedAt = updatedAt
    }
}
