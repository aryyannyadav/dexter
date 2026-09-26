//
//  DexterSuggestionStore.swift
//  leanring-buddy
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class DexterSuggestionStore: ObservableObject {
    @Published private(set) var activeSuggestions: [DexterSuggestion] = []
    let presentationState = DexterSuggestionPresentationState()

    private let persistenceStore = DexterSuggestionPersistenceStore()
    private weak var companionManager: CompanionManager?
    private var cancellables = Set<AnyCancellable>()
    private var runningSuggestionItemID: String?
    private var clearRunningSuggestionTask: Task<Void, Never>?
    private var recentAcceptedPrompts: [String] = []
    private var sawBusyExecutionSinceSuggestionAccept = false

    var hasUnreadSuggestions: Bool {
        unreadSuggestionCount > 0
    }

    var unreadSuggestionCount: Int {
        presentationState.homeSuggestions.filter { $0.isUnread }.count
    }

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager
        cancellables.removeAll()

        companionManager.dexterRuntimeUIStateStore.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reconcileRunningSuggestionOutcome()
            }
            .store(in: &cancellables)

        companionManager.dexterVoiceCoordinator.$interactionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reconcileRunningSuggestionOutcome()
            }
            .store(in: &cancellables)
    }

    /// Request-driven refresh — call after a Dexter turn or when Home opens (not on a background poll).
    func refreshSuggestionsFromAuthorizedContext() {
        guard let companionManager else { return }
        guard DexterAgentSettingsStore.shared.suggestAgentTasks else {
            activeSuggestions = []
            presentationState.updateHomeSuggestions([])
            return
        }

        let activeProfileId = companionManager.dexterProfileStore.activeProfileId
        let profileScopedRecents = companionManager.dexterRecentConversations.filter {
            guard let activeProfileId else { return true }
            return $0.dexterProfileId == activeProfileId
        }

        let evaluatedAt = Date()
        let fileWorkspace = activeProfileId.flatMap { companionManager.dexterFileWorkspaceStore.workspace(forProfileId: $0) }
        let recentWorkspaceFile = activeProfileId.flatMap {
            companionManager.dexterFileWorkspaceStore.recentFiles(forProfileId: $0, limit: 1).first?.name
        }
        let input = DexterSuggestionEngineInput(
            contextSnapshot: companionManager.lastDexterContextSnapshot,
            activeTaskDescription: companionManager.dexterActiveTaskDescription,
            workflowContextSummary: companionManager.dexterWorkflowContextSummary,
            activeWorkflowTaskTitle: companionManager.panelActiveWorkflowTask?.title,
            recentConversationTitles: profileScopedRecents.map(\.title),
            activeProfileId: activeProfileId,
            fileWorkspaceName: fileWorkspace?.name,
            fileWorkspaceIndexStatus: fileWorkspace?.indexStatus,
            fileWorkspaceRecentFileName: recentWorkspaceFile,
            evaluatedAt: evaluatedAt
        )

        let generatedRaw = DexterSuggestionEngine.generateSuggestions(
            input: input,
            persistence: persistenceStore
        )
        companionManager.refreshDexterProductCapabilities()
        let generated = DexterSuggestionCapabilityFilter.filterSuggestions(
            generatedRaw,
            capabilities: companionManager.dexterProductCapabilities,
            integrations: companionManager.dexterIntegrationService.integrations
        )

        companionManager.dexterProfileWorkSuggestionStore.refreshFromAuthorizedContext()

        let hadUnreadBefore = hasUnreadSuggestions

        activeSuggestions = generated.map { suggestion in
            var updated = suggestion
            let record = persistenceStore.record(for: suggestion.id)
            if record.lastShownAt != nil {
                updated.lifecycle = .shown
                updated.isUnread = false
            }
            if updated.dexterProfileId == nil {
                updated.dexterProfileId = activeProfileId
            }
            return updated
        }

        for suggestion in activeSuggestions {
            persistenceStore.markShown(identifier: suggestion.id)
        }

        let allProfileWork = companionManager.dexterProfileStore.profiles.flatMap { profile in
            companionManager.dexterProfileWorkSuggestionStore.suggestions(forProfileId: profile.id)
        }

        let rankedAggregated = DexterSuggestionRankingFilter.rankedHomeSuggestions(
            contextSuggestions: activeSuggestions,
            profileWorkSuggestions: allProfileWork,
            activeProfileId: nil,
            recentConversationTitles: profileScopedRecents.map(\.title),
            recentAcceptedPrompts: recentAcceptedPrompts,
            evaluatedAt: evaluatedAt
        )

        let aggregatedRotationSeed = DexterHomeSuggestionDisplayPlanner.rotationSeed(
            activeProfileId: nil,
            evaluatedAt: evaluatedAt,
            rankedItemIDs: rankedAggregated.map(\.id)
        )
        let displayAggregated = DexterHomeSuggestionDisplayPlanner.planAggregatedHome(
            rankedEligible: rankedAggregated,
            maxCount: DexterHomeSuggestionDisplayPlanner.homeDisplayLimit,
            rotationSeed: aggregatedRotationSeed
        )

        var suggestionsByProfile: [UUID: [DexterHomeSuggestionItem]] = [:]
        for profile in companionManager.dexterProfileStore.profiles {
            let profileWork = companionManager.dexterProfileWorkSuggestionStore.suggestions(forProfileId: profile.id)
            let contextForProfile = activeSuggestions.filter { suggestion in
                if let suggestionProfileId = suggestion.dexterProfileId {
                    return suggestionProfileId == profile.id
                }
                return profile.id == activeProfileId
            }
            let rankedForProfile = DexterSuggestionRankingFilter.rankedHomeSuggestions(
                contextSuggestions: contextForProfile,
                profileWorkSuggestions: profileWork,
                activeProfileId: profile.id,
                recentConversationTitles: profileScopedRecents.map(\.title),
                recentAcceptedPrompts: recentAcceptedPrompts,
                evaluatedAt: evaluatedAt
            )
            let profileRotationSeed = DexterHomeSuggestionDisplayPlanner.rotationSeed(
                activeProfileId: profile.id,
                evaluatedAt: evaluatedAt,
                rankedItemIDs: rankedForProfile.map(\.id)
            )
            suggestionsByProfile[profile.id] = DexterHomeSuggestionDisplayPlanner.plan(
                rankedEligible: rankedForProfile,
                maxCount: DexterHomeSuggestionDisplayPlanner.homeDisplayLimit,
                rotationSeed: profileRotationSeed
            )
        }

        presentationState.updatePresentation(
            aggregated: displayAggregated,
            profileSuggestionsByProfileId: suggestionsByProfile
        )

        #if DEBUG
        logSuggestionPresentationDiagnostics(
            aggregatedCount: displayAggregated.count,
            suggestionsByProfile: suggestionsByProfile,
            rankedAggregatedCount: rankedAggregated.count,
            allProfileWorkCount: allProfileWork.count,
            contextCount: activeSuggestions.count
        )
        #endif

        if !hadUnreadBefore && hasUnreadSuggestions {
            companionManager.dexterAvatarPresence.notifySuggestionAttention()
        }
    }

    func dismissHomeSuggestion(_ item: DexterHomeSuggestionItem) {
        withAnimation(DexterSuggestionMotion.exitEase) {
            presentationState.setStatus(.dismissed, for: item.id)
            switch item {
            case .context:
                persistenceStore.markDismissed(identifier: item.id)
                activeSuggestions.removeAll { $0.id == item.id }
            case .profileWork(let suggestion):
                companionManager?.dexterProfileWorkSuggestionStore.dismiss(suggestion)
            }
            removeFromHomePresentation(itemID: item.id)
        }
    }

    func acceptHomeSuggestion(_ item: DexterHomeSuggestionItem, userPromptOverride: String? = nil) {
        runningSuggestionItemID = item.id
        sawBusyExecutionSinceSuggestionAccept = false
        presentationState.setStatus(.running, for: item.id)

        switch item {
        case .context(let suggestion):
            let prompt = userPromptOverride ?? suggestion.userPromptOnAccept
            recentAcceptedPrompts.insert(prompt, at: 0)
            recentAcceptedPrompts = Array(recentAcceptedPrompts.prefix(8))
            persistenceStore.markAccepted(identifier: suggestion.id)
            activeSuggestions.removeAll { $0.id == suggestion.id }
            companionManager?.dexterActivityRecorder.recordSuggestionAccepted(suggestion)
            companionManager?.submitTextMessageToDexter(prompt)
        case .profileWork(let suggestion):
            recentAcceptedPrompts.insert(suggestion.headline, at: 0)
            companionManager?.executeProfileWorkSuggestion(suggestion)
        }
    }

    func retryHomeSuggestion(_ item: DexterHomeSuggestionItem) {
        presentationState.setStatus(.new, for: item.id)
        acceptHomeSuggestion(item)
    }

    func dismissSuggestion(identifier: String) {
        persistenceStore.markDismissed(identifier: identifier)
        activeSuggestions.removeAll { $0.id == identifier }
        removeFromHomePresentation(itemID: identifier)
    }

    func acceptSuggestion(_ suggestion: DexterSuggestion) {
        acceptHomeSuggestion(.context(suggestion))
    }

    func markSuggestionCompleted(identifier: String) {
        persistenceStore.markCompleted(identifier: identifier)
        activeSuggestions.removeAll { $0.id == identifier }
        presentationState.setStatus(.completed, for: identifier)
        removeFromHomePresentation(itemID: identifier)
    }

    func markAllSuggestionsRead() {
        activeSuggestions = activeSuggestions.map { suggestion in
            var updated = suggestion
            updated.isUnread = false
            return updated
        }
        presentationState.updatePresentation(
            aggregated: presentationState.aggregatedSuggestions,
            profileSuggestionsByProfileId: presentationState.profileSuggestionsByProfileId
        )
    }

    private func reconcileRunningSuggestionOutcome() {
        guard let runningSuggestionItemID,
              let companionManager else {
            return
        }

        let runtimeState = companionManager.dexterRuntimeUIStateStore.currentState
        let voiceState = companionManager.voiceInteractionState

        if isBusyRuntimeOrVoice(runtimeState: runtimeState, voiceState: voiceState) {
            sawBusyExecutionSinceSuggestionAccept = true
        }

        if runtimeState == .failed {
            presentationState.setStatus(.failed, for: runningSuggestionItemID)
            scheduleRunningSuggestionClear()
            return
        }

        let actionFinished = runtimeState == .done || runtimeState == .cancelled
        let conversationFinished = voiceState == .idle
            && runtimeState != .acting
            && runtimeState != .verifying
            && runtimeState != .planning
            && runtimeState != .waitingPermission
            && runtimeState != .thinking
            && runtimeState != .understanding

        if sawBusyExecutionSinceSuggestionAccept && (actionFinished || conversationFinished) {
            presentationState.setStatus(.completed, for: runningSuggestionItemID)
            persistenceStore.markCompleted(identifier: runningSuggestionItemID)
            scheduleRunningSuggestionClear()
        }
    }

    private func isBusyRuntimeOrVoice(
        runtimeState: DexterRuntimeUIState,
        voiceState: DexterVoiceInteractionState
    ) -> Bool {
        switch runtimeState {
        case .acting, .verifying, .planning, .waitingPermission, .thinking, .understanding:
            return true
        default:
            break
        }
        switch voiceState {
        case .listening, .transcribing, .thinking, .speaking:
            return true
        case .idle, .error:
            return false
        }
    }

    private func scheduleRunningSuggestionClear() {
        clearRunningSuggestionTask?.cancel()
        clearRunningSuggestionTask = Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            if let runningSuggestionItemID {
                withAnimation(DexterSuggestionMotion.exitEase) {
                    removeFromHomePresentation(itemID: runningSuggestionItemID)
                    presentationState.clearStatus(for: runningSuggestionItemID)
                }
            }
            runningSuggestionItemID = nil
        }
    }

    private func removeFromHomePresentation(itemID: String) {
        presentationState.removeSuggestionFromPresentation(itemID: itemID)
    }

    #if DEBUG
    private func logSuggestionPresentationDiagnostics(
        aggregatedCount: Int,
        suggestionsByProfile: [UUID: [DexterHomeSuggestionItem]],
        rankedAggregatedCount: Int,
        allProfileWorkCount: Int,
        contextCount: Int
    ) {
        let profileStore = companionManager?.dexterProfileStore
        let nameForProfile: (UUID) -> String = { profileId in
            profileStore?.profile(withId: profileId)?.name ?? profileId.uuidString.prefix(6).description
        }
        let perProfile = suggestionsByProfile
            .map { "\(nameForProfile($0.key))=\($0.value.count)" }
            .sorted()
            .joined(separator: ", ")
        print(
            "[DEXTER][SUGGESTIONS] home_eligible=\(aggregatedCount) ranked_pool=\(rankedAggregatedCount) " +
            "profile_work=\(allProfileWorkCount) context=\(contextCount) | \(perProfile)"
        )
    }
    #endif

}
