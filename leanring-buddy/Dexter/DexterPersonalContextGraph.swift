//
//  DexterPersonalContextGraph.swift
//  leanring-buddy
//

import Foundation

enum DexterContextGraphEntityKind: String, Equatable {
    case user
    case project
    case goal
    case task
    case commitment
    case application
    case workflow
    case preference
    case skill
    case memory
    case conversation
}

enum DexterContextGraphRelationshipKind: String, Equatable {
    case owns
    case contains
    case belongsTo
    case prefers
    case learned
    case uses
    case requires
    case hasVerificationCondition
}

struct DexterContextGraphEntity: Equatable, Identifiable {
    let id: String
    let kind: DexterContextGraphEntityKind
    let title: String
    let detail: String?
}

struct DexterContextGraphRelationship: Equatable {
    let fromEntityIdentifier: String
    let relationship: DexterContextGraphRelationshipKind
    let toEntityIdentifier: String
}

/// Lightweight graph abstraction over MemoryStore — persistence stays in PersistentMemoryStore.
enum DexterPersonalContextGraph {
    static func entities(from memoryStore: MemoryStore) -> [DexterContextGraphEntity] {
        var entities: [DexterContextGraphEntity] = []

        for entry in memoryStore.allPersistentEntries() where entry.kind == .userPreference {
            entities.append(
                DexterContextGraphEntity(
                    id: "preference:\(entry.id.uuidString)",
                    kind: .preference,
                    title: entry.title,
                    detail: entry.content
                )
            )
        }

        if let taskDescription = memoryStore.activeTaskDescription?.nonEmptyTrimmedValue {
            entities.append(
                DexterContextGraphEntity(
                    id: "task:current",
                    kind: .task,
                    title: "Current task",
                    detail: taskDescription
                )
            )
        }

        return entities
    }
}

private extension String {
    var nonEmptyTrimmedValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
