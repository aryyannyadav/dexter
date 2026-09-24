//
//  DexterPersonalContextGraphBuilder.swift
//  leanring-buddy
//

import Foundation

enum DexterPersonalContextGraphBuilder {
    static let userEntityIdentifier = "user:local"

    static func build(
        memoryStore: MemoryStore,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterPersonalContextGraphSnapshot {
        var entities: [DexterContextGraphEntity] = [
            DexterContextGraphEntity(
                id: userEntityIdentifier,
                kind: .user,
                title: "You",
                detail: nil,
                sourceIntegration: nil
            )
        ]
        var relationships: [DexterContextGraphRelationship] = []
        var sourceLabels: [String] = ["memory"]

        var workflowEntityIdentifier: String?
        var primaryProjectEntityIdentifier: String?
        var primaryTaskEntityIdentifier: String?
        var primaryGoalEntityIdentifier: String?

        if let workflowSummary = authorizedInput.workflowSummary?.nonEmptyTrimmedValue {
            workflowEntityIdentifier = "workflow:active"
            entities.append(
                DexterContextGraphEntity(
                    id: workflowEntityIdentifier!,
                    kind: .workflow,
                    title: "Active workflow",
                    detail: workflowSummary,
                    sourceIntegration: nil
                )
            )
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: userEntityIdentifier,
                    relationship: .owns,
                    toEntityIdentifier: workflowEntityIdentifier!
                )
            )
        }

        if let taskDescription = authorizedInput.currentTaskDescription?.nonEmptyTrimmedValue {
            primaryTaskEntityIdentifier = "task:current"
            entities.append(
                DexterContextGraphEntity(
                    id: primaryTaskEntityIdentifier!,
                    kind: .task,
                    title: "Current task",
                    detail: taskDescription,
                    sourceIntegration: nil
                )
            )
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: userEntityIdentifier,
                    relationship: .owns,
                    toEntityIdentifier: primaryTaskEntityIdentifier!
                )
            )
        }

        for structuredTask in authorizedInput.accountabilityTasks.prefix(5) {
            let entityIdentifier = "accountability_task:\(structuredTask.id.uuidString)"
            entities.append(
                DexterContextGraphEntity(
                    id: entityIdentifier,
                    kind: .task,
                    title: structuredTask.title,
                    detail: structuredTask.status.rawValue,
                    sourceIntegration: nil
                )
            )
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: userEntityIdentifier,
                    relationship: .owns,
                    toEntityIdentifier: entityIdentifier
                )
            )
        }

        for memory in authorizedInput.retrievedMemories {
            let entityIdentifier = "memory:\(memory.id.uuidString)"
            entities.append(
                DexterContextGraphEntity(
                    id: entityIdentifier,
                    kind: entityKind(for: memory.type),
                    title: memory.title ?? memory.type.rawValue,
                    detail: memory.content,
                    sourceIntegration: nil
                )
            )

            switch memory.type {
            case .preference:
                relationships.append(
                    DexterContextGraphRelationship(
                        fromEntityIdentifier: userEntityIdentifier,
                        relationship: .userToPreference,
                        toEntityIdentifier: entityIdentifier
                    )
                )
            case .project:
                primaryProjectEntityIdentifier = entityIdentifier
                relationships.append(
                    DexterContextGraphRelationship(
                        fromEntityIdentifier: userEntityIdentifier,
                        relationship: .userToProject,
                        toEntityIdentifier: entityIdentifier
                    )
                )
                if let taskEntityIdentifier = primaryTaskEntityIdentifier {
                    relationships.append(
                        DexterContextGraphRelationship(
                            fromEntityIdentifier: entityIdentifier,
                            relationship: .projectToTask,
                            toEntityIdentifier: taskEntityIdentifier
                        )
                    )
                }
            case .task:
                if primaryTaskEntityIdentifier == nil {
                    primaryTaskEntityIdentifier = entityIdentifier
                }
            case .goal:
                primaryGoalEntityIdentifier = entityIdentifier
            case .commitment:
                if let taskEntityIdentifier = primaryTaskEntityIdentifier {
                    relationships.append(
                        DexterContextGraphRelationship(
                            fromEntityIdentifier: taskEntityIdentifier,
                            relationship: .taskToCommitment,
                            toEntityIdentifier: entityIdentifier
                        )
                    )
                }
            case .semantic, .episodic, .workflow, .preference, .project, .task, .goal, .commitment:
                break
            }
        }

        if let goalEntityIdentifier = primaryGoalEntityIdentifier,
           let taskEntityIdentifier = primaryTaskEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: taskEntityIdentifier,
                    relationship: .taskToGoal,
                    toEntityIdentifier: goalEntityIdentifier
                )
            )
        }

        if !authorizedInput.recentConversationExchanges.isEmpty {
            let lastExchange = authorizedInput.recentConversationExchanges.last!
            let conversationEntityIdentifier = "conversation:last"
            entities.append(
                DexterContextGraphEntity(
                    id: conversationEntityIdentifier,
                    kind: .conversation,
                    title: "Last exchange",
                    detail: "You: \(lastExchange.userTranscript)",
                    sourceIntegration: nil
                )
            )
        }

        let integrationInput = DexterIntegrationProviderInput(
            authorizedInput: authorizedInput,
            linkage: DexterIntegrationLinkage(
                workflowEntityIdentifier: workflowEntityIdentifier,
                projectEntityIdentifier: primaryProjectEntityIdentifier,
                taskEntityIdentifier: primaryTaskEntityIdentifier
            )
        )
        for integrationResult in DexterIntegrationProviderRegistry.collectContributions(context: integrationInput) {
            applyIntegration(
                integrationResult,
                entities: &entities,
                relationships: &relationships,
                sourceLabels: &sourceLabels
            )
        }

        _ = memoryStore

        return DexterPersonalContextGraphSnapshot(
            entities: deduplicatedEntities(entities),
            relationships: relationships,
            authorizedSourceLabels: sourceLabels
        )
    }

    static func build(memoryStore: MemoryStore, dexterContext: DexterContext) -> DexterPersonalContextGraphSnapshot {
        build(
            memoryStore: memoryStore,
            authorizedInput: .fromDexterContext(dexterContext)
        )
    }

    static func promptSummary(from snapshot: DexterPersonalContextGraphSnapshot) -> String {
        if snapshot.entities.isEmpty {
            return "none"
        }

        var lines: [String] = []
        lines.append("Sources: \(snapshot.authorizedSourceLabels.joined(separator: ", "))")
        for entity in snapshot.entities.prefix(12) {
            let detailSuffix = entity.detail.map { " — \($0)" } ?? ""
            lines.append("- [\(entity.kind.rawValue)] \(entity.title)\(detailSuffix)")
        }
        if !snapshot.relationships.isEmpty {
            lines.append("Relationships:")
            for relationship in snapshot.relationships.prefix(10) {
                lines.append("- \(relationship.fromEntityIdentifier) \(relationship.relationship.rawValue) \(relationship.toEntityIdentifier)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func entityKind(for memoryType: DexterMemoryType) -> DexterContextGraphEntityKind {
        switch memoryType {
        case .episodic: return .memory
        case .semantic: return .memory
        case .project: return .project
        case .workflow: return .workflow
        case .preference: return .preference
        case .task: return .task
        case .goal: return .goal
        case .commitment: return .commitment
        }
    }

    private static func applyIntegration(
        _ integrationResult: DexterPersonalContextIntegrationResult?,
        entities: inout [DexterContextGraphEntity],
        relationships: inout [DexterContextGraphRelationship],
        sourceLabels: inout [String]
    ) {
        guard let integrationResult else { return }
        entities.append(contentsOf: integrationResult.entities)
        relationships.append(contentsOf: integrationResult.relationships)
        if !sourceLabels.contains(integrationResult.sourceLabel) {
            sourceLabels.append(integrationResult.sourceLabel)
        }
    }

    private static func deduplicatedEntities(_ entities: [DexterContextGraphEntity]) -> [DexterContextGraphEntity] {
        var seen: Set<String> = []
        var result: [DexterContextGraphEntity] = []
        for entity in entities {
            if seen.insert(entity.id).inserted {
                result.append(entity)
            }
        }
        return result
    }
}
