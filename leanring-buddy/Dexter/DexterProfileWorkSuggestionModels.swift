//
//  DexterProfileWorkSuggestionModels.swift
//  leanring-buddy
//

import Foundation

enum DexterProfileWorkSuggestionCategory: String, Codable, Equatable {
    case continueWork = "continue_work"
    case pickUpWhereYouLeftOff = "pick_up_where_you_left_off"
    case integration = "integration"
    case task = "task"
    case research = "research"
    case explain = "explain"
}

enum DexterProfileWorkSuggestionSourceKind: String, Codable, Equatable {
    case conversation
    case memory
    case integration
    case unfinishedDexterTask
    case failedAction
    case userCreatedTask
    case personaStarter
}

struct DexterProfileWorkSuggestionSource: Codable, Equatable {
    let kind: DexterProfileWorkSuggestionSourceKind
    let referenceIdentifier: String
    let displayDetail: String
}

enum DexterProfileWorkSuggestionAction: Codable, Equatable {
    case openConversation(conversationId: UUID)
    case runAgent(userMessage: String)
    case openIntegration(integrationId: String)
    case continueTask(taskId: UUID)
    case explain(subject: String)
    case research(query: String)
}

struct DexterProfileWorkSuggestion: Identifiable, Codable, Equatable {
    let id: String
    let dexterProfileId: UUID
    let category: DexterProfileWorkSuggestionCategory
    let sectionTitle: String
    let headline: String
    let body: String
    let primaryActionTitle: String
    let source: DexterProfileWorkSuggestionSource
    let action: DexterProfileWorkSuggestionAction
    let priority: Int
    let refreshedAt: Date
    var isUnread: Bool

    var persistenceIdentifier: String {
        if id.hasPrefix("capability_connect:") {
            return id
        }
        return "profile_work:\(dexterProfileId.uuidString):\(id)"
    }
}

struct DexterProfileWorkSuggestionEngineInput: Equatable {
    let profiles: [DexterProfile]
    let recentConversations: [DexterRecentConversationSummary]
    let persistentMemorySummaries: [DexterProfileMemorySummary]
    let activeWorkflowTaskTitle: String?
    let activeTaskDescription: String?
    let accountabilityTasks: [DexterAccountabilityTask]
    let lastFailedAction: DexterProfileFailedActionSnapshot?
    let openClawGatewayConnected: Bool
    let engineSuggestions: [DexterSuggestion]
    let lastUserMessageText: String?
    let integrations: [DexterIntegration]
    let capabilityDiscoveryReport: DexterOpenClawCapabilityDiscoveryReport
    let evaluatedAt: Date
}

struct DexterProfileMemorySummary: Equatable {
    let entryId: UUID
    let summary: String
}

struct DexterProfileFailedActionSnapshot: Equatable {
    let actionId: UUID
    let humanReadableDescription: String
    let actionType: DexterActionType
}
