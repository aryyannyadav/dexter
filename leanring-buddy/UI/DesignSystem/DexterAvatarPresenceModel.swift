//
//  DexterAvatarPresenceModel.swift
//  leanring-buddy
//

import AppKit
import Combine
import Foundation

/// Publishes avatar state derived from live Dexter signals (no decorative faking).
@MainActor
final class DexterAvatarPresenceModel: ObservableObject {
    @Published private(set) var avatarState: DexterAvatarState = .idle
    @Published private(set) var characterState: DexterCharacterState = .idle

    private weak var companionManager: CompanionManager?
    private var cancellables = Set<AnyCancellable>()
    private var ephemeralOverride: DexterCharacterState?
    private var ephemeralClearTask: Task<Void, Never>?
    private var previousRuntimeState: DexterRuntimeUIState = .idle
    private var isApplicationActive = true
    private var workspaceObserver: NSObjectProtocol?

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager
        isApplicationActive = NSApp.isActive
        publishAvatarState()

        companionManager.dexterRuntimeUIStateStore.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleRuntimeStateTransition(newState)
            }
            .store(in: &cancellables)

        companionManager.dexterVoiceCoordinator.$interactionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.publishAvatarState()
            }
            .store(in: &cancellables)

        companionManager.dexterRuntimeUIStateStore.$failurePresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.publishAvatarState()
            }
            .store(in: &cancellables)

        companionManager.$actionConfirmationPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] presentation in
                if presentation != nil {
                    DexterPersonalitySoundHooks.play(.permissionRequested)
                }
                self?.publishAvatarState()
            }
            .store(in: &cancellables)

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isApplicationActive = true
            self?.publishAvatarState()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isApplicationActive = false
            self?.publishAvatarState()
        }
    }

    func notifySuggestionAttention() {
        DexterPersonalitySoundHooks.play(.suggestion)
    }

    private func handleRuntimeStateTransition(_ newState: DexterRuntimeUIState) {
        let wasBusy = isBusyRuntimeState(previousRuntimeState)

        if newState == .waitingPermission && previousRuntimeState != .waitingPermission {
            DexterPersonalitySoundHooks.play(.permissionRequested)
        }

        if newState == .acting && !isBusyRuntimeState(previousRuntimeState) {
            DexterPersonalitySoundHooks.play(.taskStarted)
        }

        if wasBusy && newState == .done {
            flashEphemeral(.success)
            DexterPersonalitySoundHooks.play(.taskCompleted)
        }

        if newState == .failed && previousRuntimeState != .failed {
            flashEphemeral(.error)
            DexterPersonalitySoundHooks.play(.error)
        }

        previousRuntimeState = newState
        publishAvatarState()
    }

    private func flashEphemeral(_ state: DexterCharacterState) {
        ephemeralClearTask?.cancel()
        ephemeralOverride = state
        publishAvatarState()

        let flashDurationNanoseconds: UInt64 = state == .success ? 700_000_000 : 850_000_000
        ephemeralClearTask = Task {
            try? await Task.sleep(nanoseconds: flashDurationNanoseconds)
            guard !Task.isCancelled else { return }
            ephemeralOverride = nil
            publishAvatarState()
        }
    }

    private func publishAvatarState() {
        guard let companionManager else { return }
        characterState = DexterCharacterStateResolver.resolve(
            companionManager: companionManager,
            ephemeralOverride: ephemeralOverride,
            isApplicationActive: isApplicationActive
        )
        avatarState = mapCharacterStateToLegacyAvatarState(characterState)
    }

    private func mapCharacterStateToLegacyAvatarState(_ state: DexterCharacterState) -> DexterAvatarState {
        switch state {
        case .idle: return .idle
        case .listening: return .listening
        case .thinking: return .thinking
        case .speaking: return .speaking
        case .working: return .acting
        case .success: return .success
        case .error: return .error
        case .sleeping: return .sleeping
        }
    }

    private func isBusyRuntimeState(_ state: DexterRuntimeUIState) -> Bool {
        switch state {
        case .acting, .verifying, .planning, .thinking, .understanding, .listening, .waitingPermission:
            return true
        case .idle, .done, .failed, .cancelled:
            return false
        }
    }
}
