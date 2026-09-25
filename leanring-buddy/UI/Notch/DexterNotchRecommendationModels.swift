//
//  DexterNotchRecommendationModels.swift
//  leanring-buddy
//

import Foundation

enum DexterNotchRecommendationPriority: Int, Comparable, Codable {
    case low = 10
    case medium = 50
    case high = 100

    static func < (lhs: DexterNotchRecommendationPriority, rhs: DexterNotchRecommendationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum DexterNotchRecommendationKind: String, Codable, Equatable {
    case dexterStatus
    case greeting
    case activeDexter
    case pendingAgent
    case permissionRequest
    case agentFailure
    case agentCompletion
    case contextualSuggestion
    case integrationRecommendation
    case unfinishedTask
}

enum DexterNotchRecommendationSourceKind: String, Codable, Equatable {
    case runtimeState
    case actionConfirmation
    case failedAction
    case completedAction
    case profileWorkSuggestion
    case accountabilityTask
    case integrationCatalog
    case userConversation
}

struct DexterNotchRecommendationSource: Equatable, Codable {
    let kind: DexterNotchRecommendationSourceKind
    let referenceIdentifier: String
    let displayDetail: String
}

enum DexterNotchRecommendationAction: Equatable, Codable {
    case approvePendingPermission
    case cancelPendingPermission
    case openDexterHome
    case openIntegrationSettings(integrationId: String)
    case executeProfileWorkSuggestion(suggestionId: String, profileId: UUID)
    case openConversation(conversationId: UUID)
    case continueAccountabilityTask(taskId: UUID)
    case retryLastAgentAction
    case explainLastAgentFailure
    case dismiss
}

struct DexterNotchRecommendation: Identifiable, Equatable {
    let id: String
    let kind: DexterNotchRecommendationKind
    let priority: DexterNotchRecommendationPriority
    let profileName: String?
    let sectionTitle: String
    let headline: String
    let body: String
    let primaryActionTitle: String
    let secondaryActionTitle: String?
    let source: DexterNotchRecommendationSource
    let primaryAction: DexterNotchRecommendationAction
    let secondaryAction: DexterNotchRecommendationAction?

    var persistenceIdentifier: String {
        "notch_recommendation:\(id)"
    }
}

struct DexterNotchAgentCompletionSnapshot: Equatable {
    let profileName: String
    let summary: String
    let completedAt: Date
    let persistenceIdentifier: String
}
