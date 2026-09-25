//
//  DexterNotchAttentionStore.swift
//  leanring-buddy
//

import Combine
import Foundation

/// Subtle notch badge when Dexter has something the user may have missed.
@MainActor
final class DexterNotchAttentionStore: ObservableObject {
    @Published private(set) var showsAttentionBadge: Bool = false

    private weak var companionManager: CompanionManager?
    weak var chromeController: DexterNotchChromeController?
    private var cancellables = Set<AnyCancellable>()
    private var previousRuntimeState: DexterRuntimeUIState = .idle
    private var previousAssistantMessageCount: Int = 0
    private var isSuppressedUntilNextEvent = false

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager
        previousAssistantMessageCount = assistantMessageCount(in: companionManager)

        companionManager.dexterRuntimeUIStateStore.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleRuntimeStateChange(newState)
            }
            .store(in: &cancellables)

        companionManager.$actionConfirmationPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presentation in
                if presentation != nil {
                    self?.raiseAttention()
                }
            }
            .store(in: &cancellables)

        companionManager.$dexterChatMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.handleChatMessagesChanged(messages)
            }
            .store(in: &cancellables)
    }

    func clearAttentionForUserInteraction() {
        showsAttentionBadge = false
        isSuppressedUntilNextEvent = true
    }

    private func handleRuntimeStateChange(_ newState: DexterRuntimeUIState) {
        let wasActive = !previousRuntimeState.isTerminal && previousRuntimeState != .idle
        if wasActive && newState == .done {
            raiseAttention()
        }
        previousRuntimeState = newState
    }

    private func handleChatMessagesChanged(_ messages: [DexterChatMessage]) {
        let assistantCount = messages.filter { $0.role == .assistant }.count
        if assistantCount > previousAssistantMessageCount {
            raiseAttention()
        }
        previousAssistantMessageCount = assistantCount
    }

    private func raiseAttention() {
        if chromeController?.chromeMode == .expanded {
            return
        }
        if isSuppressedUntilNextEvent {
            isSuppressedUntilNextEvent = false
        }
        let wasAlreadyShowingBadge = showsAttentionBadge
        showsAttentionBadge = true
        if !wasAlreadyShowingBadge {
            companionManager?.dexterAvatarPresence.notifySuggestionAttention()
        }
    }

    private func assistantMessageCount(in companionManager: CompanionManager) -> Int {
        companionManager.dexterChatMessages.filter { $0.role == .assistant }.count
    }
}
