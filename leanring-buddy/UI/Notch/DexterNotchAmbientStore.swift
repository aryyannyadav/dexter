//
//  DexterNotchAmbientStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterNotchAmbientStore: ObservableObject {
    @Published private(set) var resolvedState: DexterAmbientResolvedState

    weak var chromeController: DexterNotchChromeController?

    private weak var companionManager: CompanionManager?
    private weak var recommendationStore: DexterNotchRecommendationStore?
    private var cancellables = Set<AnyCancellable>()
    private var previousRuntimeState: DexterRuntimeUIState = .idle
    private var ephemeralSuccessDeadline: Date?
    private var routineAnnouncementDeadline: Date?
    private var collapseEphemeralSuccessTask: Task<Void, Never>?
    private var previousAmbientState: DexterAmbientState = .idle

    init() {
        resolvedState = DexterAmbientResolvedState(
            ambientState: .idle,
            statusTitle: "Ready",
            statusDetail: "Ask Dexter",
            characterState: .idle,
            activeProfileName: "Dexter",
            phase5Suggestion: nil,
            notchRecommendation: nil
        )
    }

    func install(
        companionManager: CompanionManager,
        recommendationStore: DexterNotchRecommendationStore
    ) {
        self.companionManager = companionManager
        self.recommendationStore = recommendationStore
        previousRuntimeState = companionManager.dexterRuntimeUIStateStore.currentState

        let refresh: () -> Void = { [weak self] in
            self?.refreshResolvedState()
        }

        companionManager.dexterRuntimeUIStateStore.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleRuntimeTransition(newState)
                self?.refreshResolvedState()
            }
            .store(in: &cancellables)

        companionManager.dexterRuntimeUIStateStore.$statusDetail
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        companionManager.dexterRuntimeUIStateStore.$failurePresentation
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        companionManager.dexterVoiceCoordinator.$interactionState
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        companionManager.dexterAvatarPresence.$characterState
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        companionManager.$actionConfirmationPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presentation in
                if presentation != nil {
                    self?.chromeController?.holdExpandedForInteraction()
                }
                refresh()
            }
            .store(in: &cancellables)

        companionManager.dexterProfileStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        recommendationStore.$currentRecommendation
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        companionManager.dexterSuggestionStore.presentationState.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { _ in refresh() }
            .store(in: &cancellables)

        companionManager.dexterRoutineStore.$ambientAnnouncement
            .receive(on: DispatchQueue.main)
            .sink { [weak self] announcement in
                guard let self else { return }
                if announcement != nil {
                    routineAnnouncementDeadline = Date().addingTimeInterval(4)
                    chromeController?.brieflyExpand(durationSeconds: 3)
                } else {
                    routineAnnouncementDeadline = nil
                }
                refreshResolvedState()
            }
            .store(in: &cancellables)

        refreshResolvedState()
    }

    private func handleRuntimeTransition(_ newState: DexterRuntimeUIState) {
        let wasExecuting = previousRuntimeState == .acting
            || previousRuntimeState == .verifying
            || previousRuntimeState == .planning

        if wasExecuting && newState == .done {
            let failure = companionManager?.dexterRuntimeUIStateStore.failurePresentation
            if failure == nil {
                ephemeralSuccessDeadline = Date().addingTimeInterval(2.8)
                scheduleEphemeralSuccessClear()
            }
        }

        if newState == .acting || newState == .verifying || newState == .planning {
            ephemeralSuccessDeadline = nil
        }

        previousRuntimeState = newState
    }

    private func scheduleEphemeralSuccessClear() {
        collapseEphemeralSuccessTask?.cancel()
        collapseEphemeralSuccessTask = Task {
            try? await Task.sleep(nanoseconds: 2_900_000_000)
            guard !Task.isCancelled else { return }
            ephemeralSuccessDeadline = nil
            refreshResolvedState()
        }
    }

    private func refreshResolvedState() {
        guard let companionManager else { return }
        let phase5 = companionManager.dexterSuggestionStore.presentationState.homeSuggestions.first
        let ephemeralActive = ephemeralSuccessDeadline.map { $0 > Date() } ?? false

        var newState = DexterAmbientStateResolver.resolve(
            companionManager: companionManager,
            notchRecommendation: recommendationStore?.currentRecommendation,
            phase5Suggestion: phase5,
            ephemeralSuccessActive: ephemeralActive,
            productCapabilities: companionManager.dexterProductCapabilities
        )

        if let announcement = companionManager.dexterRoutineStore.ambientAnnouncement,
           routineAnnouncementDeadline.map({ $0 > Date() }) == true,
           companionManager.dexterRuntimeUIStateStore.currentState == .idle
            || companionManager.dexterRuntimeUIStateStore.currentState == .done {
            switch announcement {
            case .success(let routineName, let detail):
                newState = DexterAmbientResolvedState(
                    ambientState: .success,
                    statusTitle: "\(routineName) ready",
                    statusDetail: detail,
                    characterState: .success,
                    activeProfileName: newState.activeProfileName,
                    phase5Suggestion: nil,
                    notchRecommendation: recommendationStore?.currentRecommendation
                )
            case .failure(let routineName, let reason):
                newState = DexterAmbientResolvedState(
                    ambientState: .error,
                    statusTitle: "\(routineName) failed",
                    statusDetail: reason,
                    characterState: .error,
                    activeProfileName: newState.activeProfileName,
                    phase5Suggestion: nil,
                    notchRecommendation: recommendationStore?.currentRecommendation
                )
            }
        }

        if newState.ambientState != previousAmbientState {
            handleAmbientTransition(from: previousAmbientState, to: newState.ambientState)
            previousAmbientState = newState.ambientState
        }

        resolvedState = newState
    }

    private func handleAmbientTransition(from previous: DexterAmbientState, to new: DexterAmbientState) {
        guard let chromeController else { return }
        if new == .permission {
            chromeController.holdExpandedForInteraction()
            return
        }
        if new == .error {
            chromeController.brieflyExpand(durationSeconds: 4)
            return
        }
        if new == .success {
            chromeController.brieflyExpand(durationSeconds: 2.5)
            return
        }
        if new == .suggestion, previous == .idle {
            chromeController.brieflyExpand(durationSeconds: 3)
            return
        }
        if new != .idle && previous == .idle {
            chromeController.brieflyExpand(durationSeconds: 2.2)
        }
    }
}
