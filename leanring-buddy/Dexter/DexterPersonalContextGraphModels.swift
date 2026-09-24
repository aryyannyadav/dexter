//
//  DexterPersonalContextGraphModels.swift
//  leanring-buddy
//

import Foundation

enum DexterContextGraphEntityKind: String, Equatable, CaseIterable {
    case user = "USER"
    case project = "PROJECT"
    case task = "TASK"
    case goal = "GOAL"
    case commitment = "COMMITMENT"
    case application = "APPLICATION"
    case workflow = "WORKFLOW"
    case preference = "PREFERENCE"
    case memory = "MEMORY"
    case skill = "SKILL"
    case conversation = "CONVERSATION"
}

/// Canonical personal-context edges (not a graph database — in-memory view over memory + authorized context).
enum DexterContextGraphRelationshipKind: String, Equatable {
    case userToPreference = "user_to_preference"
    case userToProject = "user_to_project"
    case projectToTask = "project_to_task"
    case taskToGoal = "task_to_goal"
    case taskToCommitment = "task_to_commitment"
    case workflowToApplication = "workflow_to_application"

    case owns = "owns"
    case contains = "contains"
    case belongsTo = "belongs_to"
    case prefers = "prefers"
    case learned = "learned"
    case uses = "uses"
    case requires = "requires"
    case hasVerificationCondition = "has_verification_condition"
}

struct DexterContextGraphEntity: Equatable, Identifiable {
    let id: String
    let kind: DexterContextGraphEntityKind
    let title: String
    let detail: String?
    let sourceIntegration: String?
}

struct DexterContextGraphRelationship: Equatable {
    let fromEntityIdentifier: String
    let relationship: DexterContextGraphRelationshipKind
    let toEntityIdentifier: String
}

struct DexterPersonalContextGraphSnapshot: Equatable {
    let entities: [DexterContextGraphEntity]
    let relationships: [DexterContextGraphRelationship]
    let authorizedSourceLabels: [String]

    static let empty = DexterPersonalContextGraphSnapshot(
        entities: [],
        relationships: [],
        authorizedSourceLabels: []
    )
}

enum DexterPersonalContextQueryKind: Equatable {
    case whereWasI
    case whatWasIDoing
    case continueWhereLeftOff
    case catchMeUp
    case whatShouldIDoNext
}

struct DexterAuthorizedPersonalContextInput: Equatable {
    let activeApplicationName: String?
    let activeApplicationBundleIdentifier: String?
    let activeWindowTitle: String?
    let browserPageTitle: String?
    let browserPageURL: String?
    let currentTaskDescription: String?
    let workflowSummary: String?
    let recentConversationExchanges: [DexterConversationExchange]
    let recentActionSummaries: [String]
    let retrievedMemories: [DexterStructuredMemoryRecord]
    let accountabilityTasks: [DexterAccountabilityTask]
    let selectedTextSnippet: String?

    static func fromDexterContext(_ context: DexterContext) -> DexterAuthorizedPersonalContextInput {
        let applicationAvailable = context.activeApplication.availability == .available
        let windowAvailable = context.activeWindow.availability == .available

        return DexterAuthorizedPersonalContextInput(
            activeApplicationName: applicationAvailable ? context.activeApplication.localizedName : nil,
            activeApplicationBundleIdentifier: applicationAvailable ? context.activeApplication.bundleIdentifier : nil,
            activeWindowTitle: windowAvailable ? context.activeWindow.title : nil,
            browserPageTitle: nil,
            browserPageURL: nil,
            currentTaskDescription: context.currentTask.currentTaskDescription,
            workflowSummary: context.persistentMemory.workflowContext?.summary,
            recentConversationExchanges: context.conversation.recentExchanges,
            recentActionSummaries: context.recentActions.recentActions.map(\.summary),
            retrievedMemories: context.persistentMemory.retrievedMemories,
            accountabilityTasks: context.currentTask.accountabilitySnapshot.openTasks,
            selectedTextSnippet: context.selectedText.selectedText
        )
    }

    static func fromDexterContextPacket(_ packet: DexterContextPacket) -> DexterAuthorizedPersonalContextInput {
        let applicationAvailable = packet.activeApplication?.availability == .available
        let windowAvailable = packet.activeWindow?.availability == .available
        let browser = packet.browserContext

        return DexterAuthorizedPersonalContextInput(
            activeApplicationName: applicationAvailable ? packet.activeApplication?.localizedName : nil,
            activeApplicationBundleIdentifier: applicationAvailable ? packet.activeApplication?.bundleIdentifier : nil,
            activeWindowTitle: windowAvailable ? packet.activeWindow?.title : nil,
            browserPageTitle: browser?.availability == .available ? browser?.inferredPageTitle : nil,
            browserPageURL: browser?.availability == .available ? browser?.inferredPageURL : nil,
            currentTaskDescription: packet.currentTask?.currentTaskDescription,
            workflowSummary: packet.memory?.workflowContext?.summary,
            recentConversationExchanges: packet.conversation?.recentExchanges ?? [],
            recentActionSummaries: packet.recentActions?.recentActions.map(\.summary) ?? [],
            retrievedMemories: packet.memory?.retrievedMemories ?? [],
            accountabilityTasks: packet.currentTask?.accountabilitySnapshot.openTasks ?? [],
            selectedTextSnippet: packet.selectedText?.selectedText
        )
    }

    static func memoryOnly(
        memoryStore: MemoryStore,
        userMessage: String
    ) -> DexterAuthorizedPersonalContextInput {
        DexterAuthorizedPersonalContextInput(
            activeApplicationName: nil,
            activeApplicationBundleIdentifier: nil,
            activeWindowTitle: nil,
            browserPageTitle: nil,
            browserPageURL: nil,
            currentTaskDescription: memoryStore.activeTaskDescription,
            workflowSummary: memoryStore.workflowContext?.summary,
            recentConversationExchanges: memoryStore.recentExchanges(limit: 5),
            recentActionSummaries: [],
            retrievedMemories: memoryStore.persistentMemoryContext(forQuery: userMessage, limit: 6).retrievedMemories,
            accountabilityTasks: memoryStore.allAccountabilityTasks(),
            selectedTextSnippet: nil
        )
    }
}
