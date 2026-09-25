//
//  DexterSuggestionModels.swift
//  leanring-buddy
//

import Foundation

enum DexterSuggestionKind: String, Codable, CaseIterable {
    case explainError
    case summarizePage
    case finishTask
    case organizeFiles
    case continueWhereLeftOff
}

/// What accepting a suggestion is allowed to start (never auto-executed).
enum DexterSuggestionOutcome: String, Codable, Equatable {
    case conversation
    case teaching
    case action
    case agentTask
}

enum DexterSuggestionLifecycle: String, Codable, Equatable {
    case new
    case shown
    case dismissed
    case accepted
    case completed
}

enum DexterSuggestionPresentationStatus: String, Codable, Equatable {
    case new
    case dismissed
    case running
    case completed
    case failed
}

enum DexterSuggestionSource: String, Codable, Equatable {
    case screenContext
    case activeApplication
    case browserContext
    case recentConversation
    case unfinishedTask
    case integration
    case workflow
    case currentDexter
    case recentFailure
    case pendingAction

    var displayLabel: String {
        switch self {
        case .screenContext: return "Screen context"
        case .activeApplication: return "Active app"
        case .browserContext: return "Browser"
        case .recentConversation: return "Recent chat"
        case .unfinishedTask: return "Unfinished task"
        case .integration: return "Integration"
        case .workflow: return "Workflow"
        case .currentDexter: return "Active Dexter"
        case .recentFailure: return "Recent action"
        case .pendingAction: return "Pending action"
        }
    }
}

struct DexterSuggestionAdjustOption: Equatable, Codable {
    let title: String
    let userPrompt: String
}

struct DexterSuggestion: Identifiable, Equatable, Codable {
    /// Stable key for persistence (kind + grounding fingerprint).
    let id: String
    let kind: DexterSuggestionKind
    let title: String
    let explanation: String
    let noticedDetail: String
    let primaryActionTitle: String
    let secondaryActionTitle: String?
    let userPromptOnAccept: String
    let outcome: DexterSuggestionOutcome
    var lifecycle: DexterSuggestionLifecycle
    var isUnread: Bool
    let groundedAt: Date
    var dexterProfileId: UUID?
    let source: DexterSuggestionSource
    let priority: Int
    let accentIndex: Int
    let expiresAt: Date?
    let contextFingerprint: String?
    let adjustOptions: [DexterSuggestionAdjustOption]?

    var subtitle: String { explanation }

    init(
        id: String,
        kind: DexterSuggestionKind,
        title: String,
        explanation: String,
        noticedDetail: String,
        primaryActionTitle: String,
        secondaryActionTitle: String? = "Not now",
        userPromptOnAccept: String,
        outcome: DexterSuggestionOutcome,
        lifecycle: DexterSuggestionLifecycle = .new,
        isUnread: Bool = true,
        groundedAt: Date = Date(),
        dexterProfileId: UUID? = nil,
        source: DexterSuggestionSource = .screenContext,
        priority: Int = 50,
        accentIndex: Int = 0,
        expiresAt: Date? = nil,
        contextFingerprint: String? = nil,
        adjustOptions: [DexterSuggestionAdjustOption]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.explanation = explanation
        self.noticedDetail = noticedDetail
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.userPromptOnAccept = userPromptOnAccept
        self.outcome = outcome
        self.lifecycle = lifecycle
        self.isUnread = isUnread
        self.groundedAt = groundedAt
        self.dexterProfileId = dexterProfileId
        self.source = source
        self.priority = priority
        self.accentIndex = accentIndex
        self.expiresAt = expiresAt
        self.contextFingerprint = contextFingerprint
        self.adjustOptions = adjustOptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(DexterSuggestionKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        explanation = try container.decode(String.self, forKey: .explanation)
        noticedDetail = try container.decode(String.self, forKey: .noticedDetail)
        primaryActionTitle = try container.decode(String.self, forKey: .primaryActionTitle)
        secondaryActionTitle = try container.decodeIfPresent(String.self, forKey: .secondaryActionTitle)
        userPromptOnAccept = try container.decode(String.self, forKey: .userPromptOnAccept)
        outcome = try container.decode(DexterSuggestionOutcome.self, forKey: .outcome)
        lifecycle = try container.decodeIfPresent(DexterSuggestionLifecycle.self, forKey: .lifecycle) ?? .new
        isUnread = try container.decodeIfPresent(Bool.self, forKey: .isUnread) ?? true
        groundedAt = try container.decodeIfPresent(Date.self, forKey: .groundedAt) ?? Date()
        dexterProfileId = try container.decodeIfPresent(UUID.self, forKey: .dexterProfileId)
        source = try container.decodeIfPresent(DexterSuggestionSource.self, forKey: .source) ?? .screenContext
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 50
        accentIndex = try container.decodeIfPresent(Int.self, forKey: .accentIndex) ?? 0
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        contextFingerprint = try container.decodeIfPresent(String.self, forKey: .contextFingerprint)
        adjustOptions = try container.decodeIfPresent([DexterSuggestionAdjustOption].self, forKey: .adjustOptions)
    }
}

struct DexterSuggestionEngineInput: Equatable {
    let contextSnapshot: DexterContextSnapshot?
    let activeTaskDescription: String?
    let workflowContextSummary: String?
    let activeWorkflowTaskTitle: String?
    let recentConversationTitles: [String]
    let activeProfileId: UUID?
    let fileWorkspaceName: String?
    let fileWorkspaceIndexStatus: DexterFileWorkspaceIndexStatus?
    let fileWorkspaceRecentFileName: String?
    let evaluatedAt: Date
}
