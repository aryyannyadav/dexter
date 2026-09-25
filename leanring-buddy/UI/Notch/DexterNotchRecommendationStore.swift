//
//  DexterNotchRecommendationStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterNotchRecommendationStore: ObservableObject {
    @Published private(set) var currentRecommendation: DexterNotchRecommendation?

    private let persistenceStore = DexterSuggestionPersistenceStore()
    private weak var companionManager: CompanionManager?
    private var cancellables = Set<AnyCancellable>()
    private var previousRuntimeState: DexterRuntimeUIState = .idle
    private var pendingAgentCompletion: DexterNotchAgentCompletionSnapshot?

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager
        previousRuntimeState = companionManager.dexterRuntimeUIStateStore.currentState

        companionManager.dexterRuntimeUIStateStore.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleRuntimeStateChange(newState)
            }
            .store(in: &cancellables)

        companionManager.dexterRuntimeUIStateStore.$failurePresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.$actionConfirmationPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.dexterVoiceCoordinator.$interactionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.dexterRuntimeUIStateStore.$statusDetail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.$dexterChatMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.dexterProfileWorkSuggestionStore.$suggestionsByProfileId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.dexterProfileStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.dexterIntegrationService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        companionManager.openClawGatewayHealthMonitor.$capabilityDiscoveryReport
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshRecommendation() }
            .store(in: &cancellables)

        refreshRecommendation()
    }

    func dismissCurrentRecommendation() {
        guard let recommendation = currentRecommendation else { return }
        markRecommendationHandled(recommendation, completed: false)
        refreshRecommendation()
    }

    func handlePrimaryAction(for recommendation: DexterNotchRecommendation) {
        companionManager?.handleNotchRecommendationAction(recommendation.primaryAction, recommendation: recommendation)
        if recommendation.kind == .agentCompletion {
            markRecommendationHandled(recommendation, completed: true)
            pendingAgentCompletion = nil
        } else         if recommendation.kind == .integrationRecommendation {
            let sharedPersistenceId = sharedCapabilityPersistenceIdentifier(for: recommendation)
            persistenceStore.markAccepted(identifier: sharedPersistenceId)
        } else if recommendation.kind != .permissionRequest {
            persistenceStore.markAccepted(identifier: recommendation.persistenceIdentifier)
        }
        refreshRecommendation()
    }

    func handleSecondaryAction(for recommendation: DexterNotchRecommendation) {
        let action = recommendation.secondaryAction ?? .dismiss
        companionManager?.handleNotchRecommendationAction(action, recommendation: recommendation)
        markRecommendationHandled(recommendation, completed: recommendation.kind == .agentCompletion)
        refreshRecommendation()
    }

    private func sharedCapabilityPersistenceIdentifier(for recommendation: DexterNotchRecommendation) -> String {
        "capability_connect:\(recommendation.source.referenceIdentifier)"
    }

    private func markRecommendationHandled(_ recommendation: DexterNotchRecommendation, completed: Bool) {
        let persistenceIdentifier = recommendation.kind == .integrationRecommendation
            ? sharedCapabilityPersistenceIdentifier(for: recommendation)
            : recommendation.persistenceIdentifier
        if completed {
            persistenceStore.markCompleted(identifier: persistenceIdentifier)
        } else {
            persistenceStore.markDismissed(identifier: persistenceIdentifier)
        }
        if recommendation.kind == .agentCompletion {
            pendingAgentCompletion = nil
        }
    }

    private func handleRuntimeStateChange(_ newState: DexterRuntimeUIState) {
        let wasExecutingAction = previousRuntimeState == .acting
            || previousRuntimeState == .verifying
            || previousRuntimeState == .waitingPermission
            || previousRuntimeState == .planning

        if wasExecutingAction && newState == .done {
            captureAgentCompletionSnapshot()
        }
        if newState == .failed {
            pendingAgentCompletion = nil
        }
        if newState == .acting || newState == .planning || newState == .verifying {
            pendingAgentCompletion = nil
        }

        previousRuntimeState = newState
        refreshRecommendation()
    }

    private func captureAgentCompletionSnapshot() {
        guard let companionManager else { return }
        let summary = companionManager.panelLastActionSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSummary = (summary?.isEmpty == false) ? summary! : "Dexter finished the last step."
        let profileName = companionManager.dexterProfileStore.activeProfile?.name ?? "Dexter"
        let identifier = "completion:\(UUID().uuidString)"
        pendingAgentCompletion = DexterNotchAgentCompletionSnapshot(
            profileName: profileName,
            summary: resolvedSummary,
            completedAt: Date(),
            persistenceIdentifier: "notch_recommendation:\(identifier)"
        )
    }

    private func refreshRecommendation() {
        guard let companionManager else { return }

        let runtimeStore = companionManager.dexterRuntimeUIStateStore
        let activeProfile = companionManager.dexterProfileStore.activeProfile
        let profileSuggestions = activeProfile.map {
            companionManager.dexterProfileWorkSuggestionStore.suggestions(forProfileId: $0.id)
        } ?? []

        let lastUserMessage = companionManager.dexterChatMessages.last(where: { $0.role == .user })?.text
        let failedAction = companionManager.lastFailedDexterActionSnapshot()

        let input = DexterNotchRecommendationEngine.Input(
            runtimeState: runtimeStore.currentState,
            runtimeDetail: runtimeStore.statusDetail,
            failurePresentation: runtimeStore.failurePresentation,
            voiceInteractionState: companionManager.voiceInteractionState,
            actionConfirmation: companionManager.actionConfirmationPresentation,
            activeProfileName: activeProfile?.name,
            activeProfileId: activeProfile?.id,
            profileWorkSuggestions: profileSuggestions,
            openAccountabilityTasks: companionManager.openAccountabilityTasks(),
            integrations: companionManager.dexterIntegrationService.integrations,
            capabilityDiscoveryReport: companionManager.openClawGatewayHealthMonitor.capabilityDiscoveryReport,
            openClawGatewayConnected: companionManager.openClawGatewayHealthMonitor.connectionState.isConnected,
            lastUserMessageText: lastUserMessage,
            agentCompletionSnapshot: pendingAgentCompletion,
            lastFailedActionId: failedAction?.actionId,
            lastFailedActionDescription: failedAction?.humanReadableDescription,
            userFirstName: companionManager.dexterHomeUserFirstName,
            evaluatedAt: Date()
        )

        currentRecommendation = DexterNotchRecommendationEngine.resolve(
            input: input,
            persistence: persistenceStore
        )
    }
}
