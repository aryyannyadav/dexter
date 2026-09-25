//
//  DexterProfileWorkSuggestionStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterProfileWorkSuggestionStore: ObservableObject {
    @Published var suggestionsByProfileId: [UUID: [DexterProfileWorkSuggestion]] = [:]
    @Published private(set) var dashboardHighlights: [DexterProfileWorkSuggestion] = []

    private let persistenceStore = DexterSuggestionPersistenceStore()
    private weak var companionManager: CompanionManager?

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager
    }

    func refreshFromAuthorizedContext() {
        guard let companionManager else { return }
        guard DexterAgentSettingsStore.shared.suggestAgentTasks else {
            suggestionsByProfileId = [:]
            dashboardHighlights = []
            return
        }

        let evaluatedAt = Date()
        let memorySummaries = companionManager.dexterPersistentMemoryEntries.prefix(3).map { entry in
            let summary = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? entry.content
                : entry.title
            return DexterProfileMemorySummary(entryId: entry.id, summary: summary)
        }

        let failedActionSnapshot = companionManager.lastFailedDexterActionSnapshot()

        let activeProfileId = companionManager.dexterProfileStore.activeProfileId
        let fileWorkspace = activeProfileId.flatMap { companionManager.dexterFileWorkspaceStore.workspace(forProfileId: $0) }
        let recentWorkspaceFile = activeProfileId.flatMap {
            companionManager.dexterFileWorkspaceStore.recentFiles(forProfileId: $0, limit: 1).first?.name
        }
        let engineInput = DexterSuggestionEngineInput(
            contextSnapshot: companionManager.lastDexterContextSnapshot,
            activeTaskDescription: companionManager.dexterActiveTaskDescription,
            workflowContextSummary: companionManager.dexterWorkflowContextSummary,
            activeWorkflowTaskTitle: companionManager.panelActiveWorkflowTask?.title,
            recentConversationTitles: companionManager.dexterRecentConversations.map(\.title),
            activeProfileId: activeProfileId,
            fileWorkspaceName: fileWorkspace?.name,
            fileWorkspaceIndexStatus: fileWorkspace?.indexStatus,
            fileWorkspaceRecentFileName: recentWorkspaceFile,
            evaluatedAt: evaluatedAt
        )

        let engineSuggestions = DexterSuggestionEngine.generateSuggestions(
            input: engineInput,
            persistence: persistenceStore
        )

        let lastUserMessage = companionManager.dexterChatMessages.last(where: { $0.role == .user })?.text
        let healthMonitor = companionManager.openClawGatewayHealthMonitor

        let workInput = DexterProfileWorkSuggestionEngineInput(
            profiles: companionManager.dexterProfileStore.profiles,
            recentConversations: companionManager.dexterRecentConversations,
            persistentMemorySummaries: Array(memorySummaries),
            activeWorkflowTaskTitle: companionManager.panelActiveWorkflowTask?.title,
            activeTaskDescription: companionManager.dexterActiveTaskDescription,
            accountabilityTasks: companionManager.openAccountabilityTasks(),
            lastFailedAction: failedActionSnapshot,
            openClawGatewayConnected: healthMonitor.connectionState.isConnected,
            engineSuggestions: engineSuggestions,
            lastUserMessageText: lastUserMessage,
            integrations: companionManager.dexterIntegrationService.integrations,
            capabilityDiscoveryReport: healthMonitor.capabilityDiscoveryReport,
            evaluatedAt: evaluatedAt
        )

        let generated = DexterProfileWorkSuggestionEngine.generateSuggestions(
            input: workInput,
            persistence: persistenceStore
        )

        var decorated: [UUID: [DexterProfileWorkSuggestion]] = [:]
        for (profileId, suggestions) in generated {
            decorated[profileId] = suggestions.map { suggestion in
                var copy = suggestion
                let record = persistenceStore.record(for: suggestion.persistenceIdentifier)
                copy.isUnread = record.lastShownAt == nil
                return copy
            }
            for suggestion in decorated[profileId] ?? [] {
                persistenceStore.markShown(identifier: suggestion.persistenceIdentifier, at: evaluatedAt)
            }
            companionManager.dexterProfileStore.refreshCachedWorkSuggestions(
                profileId: profileId,
                suggestions: decorated[profileId] ?? []
            )
        }

        suggestionsByProfileId = decorated
        dashboardHighlights = DexterProfileWorkSuggestionEngine.homeDashboardSuggestions(from: decorated)
    }

    func dismiss(_ suggestion: DexterProfileWorkSuggestion) {
        persistenceStore.markDismissed(identifier: suggestion.persistenceIdentifier)
        removeSuggestionFromPublishedState(suggestion)
    }

    func markAccepted(_ suggestion: DexterProfileWorkSuggestion) {
        persistenceStore.markAccepted(identifier: suggestion.persistenceIdentifier)
        removeSuggestionFromPublishedState(suggestion)
    }

    func suggestions(forProfileId profileId: UUID) -> [DexterProfileWorkSuggestion] {
        suggestionsByProfileId[profileId] ?? []
    }

    func suggestionsForHome(activeProfileId: UUID?) -> [DexterProfileWorkSuggestion] {
        if let activeProfileId {
            return suggestions(forProfileId: activeProfileId)
        }
        return dashboardHighlights
    }

    func hasUnreadSuggestions(forProfileId profileId: UUID) -> Bool {
        suggestions(forProfileId: profileId).contains { $0.isUnread }
    }

    private func removeSuggestionFromPublishedState(_ suggestion: DexterProfileWorkSuggestion) {
        var updatedSuggestionsByProfileId = suggestionsByProfileId
        updatedSuggestionsByProfileId[suggestion.dexterProfileId]?.removeAll { $0.id == suggestion.id }
        suggestionsByProfileId = updatedSuggestionsByProfileId
        dashboardHighlights.removeAll { $0.id == suggestion.id && $0.dexterProfileId == suggestion.dexterProfileId }
        companionManager?.dexterProfileStore.refreshCachedWorkSuggestions(
            profileId: suggestion.dexterProfileId,
            suggestions: updatedSuggestionsByProfileId[suggestion.dexterProfileId] ?? []
        )
    }
}
