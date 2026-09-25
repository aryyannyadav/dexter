//
//  DexterProfileWorkSuggestionEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterProfileWorkSuggestionEngine {
    static let maxSuggestionsPerProfile = 1
    static let maxHomeDashboardSuggestions = 3

    static func generateSuggestions(
        input: DexterProfileWorkSuggestionEngineInput,
        persistence: DexterSuggestionPersistenceStore
    ) -> [UUID: [DexterProfileWorkSuggestion]] {
        var result: [UUID: [DexterProfileWorkSuggestion]] = [:]

        for profile in input.profiles {
            guard profile.permissions.allowsProactiveSuggestions else {
                result[profile.id] = []
                continue
            }

            var candidates: [DexterProfileWorkSuggestion] = []

            if let capabilitySuggestion = capabilityConnectSuggestion(profile: profile, input: input) {
                candidates.append(capabilitySuggestion)
            }
            if let failedAction = failedActionSuggestion(profile: profile, input: input) {
                candidates.append(failedAction)
            }
            if let taskSuggestion = unfinishedTaskSuggestion(profile: profile, input: input) {
                candidates.append(taskSuggestion)
            }
            if let accountabilitySuggestion = userCreatedTaskSuggestion(profile: profile, input: input) {
                candidates.append(accountabilitySuggestion)
            }
            if let integrationSuggestion = integrationSuggestion(profile: profile, input: input) {
                candidates.append(integrationSuggestion)
            }
            if let memorySuggestion = memorySuggestion(profile: profile, input: input) {
                candidates.append(memorySuggestion)
            }
            if let conversationSuggestion = continueConversationSuggestion(profile: profile, input: input) {
                candidates.append(conversationSuggestion)
            }
            if let engineMapped = engineSuggestion(profile: profile, input: input) {
                candidates.append(engineMapped)
            }

            let filtered = candidates
                .filter { persistence.shouldOfferSuggestion(identifier: $0.persistenceIdentifier, now: input.evaluatedAt) }
                .sorted { $0.priority > $1.priority }
                .prefix(maxSuggestionsPerProfile)

            result[profile.id] = Array(filtered)
        }

        return result
    }

    static func homeDashboardSuggestions(
        from suggestionsByProfile: [UUID: [DexterProfileWorkSuggestion]]
    ) -> [DexterProfileWorkSuggestion] {
        let flattened = suggestionsByProfile.values.flatMap { $0 }
        return flattened
            .sorted { $0.priority > $1.priority }
            .prefix(maxHomeDashboardSuggestions)
            .map { $0 }
    }

    private static func capabilityConnectSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        guard let lastUserMessage = input.lastUserMessageText,
              !lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let evaluationInput = DexterCapabilityAwareSuggestionEngine.EvaluationInput(
            userMessageText: lastUserMessage,
            integrations: input.integrations,
            capabilityDiscoveryReport: input.capabilityDiscoveryReport,
            gatewayConnected: input.openClawGatewayConnected
        )

        guard let suggestion = DexterCapabilityAwareSuggestionEngine.connectSuggestion(from: evaluationInput) else {
            return nil
        }

        return DexterProfileWorkSuggestion(
            id: suggestion.persistenceIdentifier,
            dexterProfileId: profile.id,
            category: .integration,
            sectionTitle: "CAPABILITY",
            headline: suggestion.headline,
            body: suggestion.body,
            primaryActionTitle: suggestion.primaryActionTitle,
            source: DexterProfileWorkSuggestionSource(
                kind: .integration,
                referenceIdentifier: suggestion.integrationIdForSettings,
                displayDetail: suggestion.requirement.intentSummary
            ),
            action: .openIntegration(integrationId: suggestion.integrationIdForSettings),
            priority: 98,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func failedActionSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        guard profileMatchesBuilderOrDeveloper(profile),
              let failedAction = input.lastFailedAction else {
            return nil
        }

        let mentionsOpenClaw = failedAction.humanReadableDescription.lowercased().contains("openclaw")
            || failedAction.actionType == .openApplication
            || failedAction.actionType == .click

        let body: String
        let action: DexterProfileWorkSuggestionAction
        if mentionsOpenClaw, profile.connectedIntegrations.contains("openclaw-gateway") {
            body = "Your \(failedAction.humanReadableDescription.lowercased()) failed. Want me to inspect the integration?"
            action = .openIntegration(integrationId: "openclaw-gateway")
        } else {
            body = "Your \(failedAction.humanReadableDescription.lowercased()) did not verify. Want me to investigate what happened?"
            action = .runAgent(
                userMessage: "Investigate why this action failed and suggest a safe next step: \(failedAction.humanReadableDescription)"
            )
        }

        return DexterProfileWorkSuggestion(
            id: "failed_action:\(failedAction.actionId.uuidString)",
            dexterProfileId: profile.id,
            category: .continueWork,
            sectionTitle: "CONTINUE WORK",
            headline: failedAction.humanReadableDescription,
            body: body,
            primaryActionTitle: "Investigate",
            source: DexterProfileWorkSuggestionSource(
                kind: .failedAction,
                referenceIdentifier: failedAction.actionId.uuidString,
                displayDetail: failedAction.humanReadableDescription
            ),
            action: action,
            priority: 100,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func continueConversationSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        let profileRecents = input.recentConversations
            .filter { $0.dexterProfileId == profile.id }
            .sorted { $0.lastUpdated > $1.lastUpdated }
        guard let recentConversation = profileRecents.first else { return nil }

        let topicLine = "Continue your \(recentConversation.title) topic."

        return DexterProfileWorkSuggestion(
            id: "conversation:\(recentConversation.id.uuidString)",
            dexterProfileId: profile.id,
            category: .pickUpWhereYouLeftOff,
            sectionTitle: "PICK UP WHERE YOU LEFT OFF",
            headline: recentConversation.title,
            body: topicLine,
            primaryActionTitle: "Continue",
            source: DexterProfileWorkSuggestionSource(
                kind: .conversation,
                referenceIdentifier: recentConversation.id.uuidString,
                displayDetail: recentConversation.title
            ),
            action: .openConversation(conversationId: recentConversation.id),
            priority: 80,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func unfinishedTaskSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        guard profileMatchesBuilderOrPersonal(profile) else { return nil }

        let workflowTitle = input.activeWorkflowTaskTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let memoryTask = input.activeTaskDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let taskLine = !workflowTitle.isEmpty ? workflowTitle : memoryTask
        guard !taskLine.isEmpty else { return nil }

        return DexterProfileWorkSuggestion(
            id: "dexter_task:\(taskLine.hashValue)",
            dexterProfileId: profile.id,
            category: .task,
            sectionTitle: "CONTINUE WORK",
            headline: taskLine,
            body: "You have an unfinished Dexter task. Want help with the next step?",
            primaryActionTitle: "Continue task",
            source: DexterProfileWorkSuggestionSource(
                kind: .unfinishedDexterTask,
                referenceIdentifier: taskLine,
                displayDetail: taskLine
            ),
            action: .runAgent(userMessage: "Help me finish this task: \(taskLine)"),
            priority: 90,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func userCreatedTaskSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        guard profile.id == DexterSeedProfileIdentifier.personal else { return nil }
        guard let openTask = input.accountabilityTasks.first(where: { $0.isOpen }) else { return nil }

        return DexterProfileWorkSuggestion(
            id: "user_task:\(openTask.id.uuidString)",
            dexterProfileId: profile.id,
            category: .task,
            sectionTitle: "CONTINUE WORK",
            headline: openTask.title,
            body: "You asked Dexter to track this task. Ready to continue?",
            primaryActionTitle: "Continue task",
            source: DexterProfileWorkSuggestionSource(
                kind: .userCreatedTask,
                referenceIdentifier: openTask.id.uuidString,
                displayDetail: openTask.title
            ),
            action: .continueTask(taskId: openTask.id),
            priority: 88,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func integrationSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        guard profile.connectedIntegrations.contains("openclaw-gateway") else { return nil }
        guard !input.openClawGatewayConnected else { return nil }

        return DexterProfileWorkSuggestion(
            id: "integration:openclaw-gateway",
            dexterProfileId: profile.id,
            category: .integration,
            sectionTitle: "CONTINUE WORK",
            headline: "OpenClaw is disconnected",
            body: "Computer actions need a connected OpenClaw node. Open Integrations to reconnect.",
            primaryActionTitle: "Open integration",
            source: DexterProfileWorkSuggestionSource(
                kind: .integration,
                referenceIdentifier: "openclaw-gateway",
                displayDetail: "Gateway not connected"
            ),
            action: .openIntegration(integrationId: "openclaw-gateway"),
            priority: 85,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func memorySuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        guard profile.id == DexterSeedProfileIdentifier.researcher else { return nil }
        guard let memory = input.persistentMemorySummaries.first else { return nil }

        return DexterProfileWorkSuggestion(
            id: "memory:\(memory.entryId.uuidString)",
            dexterProfileId: profile.id,
            category: .research,
            sectionTitle: "PICK UP WHERE YOU LEFT OFF",
            headline: memory.summary,
            body: "You saved this in Dexter memory. Want a quick recap?",
            primaryActionTitle: "Research",
            source: DexterProfileWorkSuggestionSource(
                kind: .memory,
                referenceIdentifier: memory.entryId.uuidString,
                displayDetail: memory.summary
            ),
            action: .research(query: "Summarize what I saved about: \(memory.summary)"),
            priority: 75,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func engineSuggestion(
        profile: DexterProfile,
        input: DexterProfileWorkSuggestionEngineInput
    ) -> DexterProfileWorkSuggestion? {
        let allowedKinds = allowedEngineKinds(for: profile.id)
        guard let engineSuggestion = input.engineSuggestions.first(where: { allowedKinds.contains($0.kind) }) else {
            return nil
        }

        let category: DexterProfileWorkSuggestionCategory
        let action: DexterProfileWorkSuggestionAction
        switch engineSuggestion.kind {
        case .explainError:
            category = .explain
            action = .explain(subject: engineSuggestion.noticedDetail)
        case .summarizePage:
            category = .research
            action = .research(query: engineSuggestion.userPromptOnAccept)
        case .finishTask, .organizeFiles, .continueWhereLeftOff:
            category = .continueWork
            action = .runAgent(userMessage: engineSuggestion.userPromptOnAccept)
        }

        return DexterProfileWorkSuggestion(
            id: "engine:\(engineSuggestion.id)",
            dexterProfileId: profile.id,
            category: category,
            sectionTitle: category == .explain ? "CONTINUE WORK" : "PICK UP WHERE YOU LEFT OFF",
            headline: engineSuggestion.noticedDetail,
            body: engineSuggestion.title,
            primaryActionTitle: engineSuggestion.primaryActionTitle,
            source: DexterProfileWorkSuggestionSource(
                kind: .unfinishedDexterTask,
                referenceIdentifier: engineSuggestion.id,
                displayDetail: engineSuggestion.noticedDetail
            ),
            action: action,
            priority: 70,
            refreshedAt: input.evaluatedAt,
            isUnread: true
        )
    }

    private static func allowedEngineKinds(for profileId: UUID) -> Set<DexterSuggestionKind> {
        switch profileId {
        case DexterSeedProfileIdentifier.studyBuddy:
            return [.summarizePage, .continueWhereLeftOff, .explainError]
        case DexterSeedProfileIdentifier.builder:
            return [.explainError, .finishTask]
        case DexterSeedProfileIdentifier.researcher:
            return [.summarizePage]
        case DexterSeedProfileIdentifier.personal:
            return [.finishTask, .organizeFiles]
        default:
            return Set(DexterSuggestionKind.allCases)
        }
    }

    private static func profileMatchesBuilderOrDeveloper(_ profile: DexterProfile) -> Bool {
        profile.id == DexterSeedProfileIdentifier.builder
            || profile.enabledSkills.contains(DexterSkillIdentifier.coding.rawValue)
    }

    private static func profileMatchesBuilderOrPersonal(_ profile: DexterProfile) -> Bool {
        profile.id == DexterSeedProfileIdentifier.builder
            || profile.id == DexterSeedProfileIdentifier.personal
    }
}
