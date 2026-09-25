//
//  DexterAgentHUDController.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterAgentHUDController: ObservableObject {
    @Published private(set) var holdsTerminalResultUntil: Date?

    private weak var companionManager: CompanionManager?
    private var cancellables = Set<AnyCancellable>()
    private var lastTerminalExecutionIdentifier: UUID?

    func install(companionManager: CompanionManager) {
        self.companionManager = companionManager

        companionManager.dexterRuntimeUIStateStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncTerminalHoldState()
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        companionManager.$actionConfirmationPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var holdsTerminalResult: Bool {
        guard let holdsTerminalResultUntil else { return false }
        return Date() <= holdsTerminalResultUntil
    }

    var presentation: DexterAgentHUDPresentation {
        guard let companionManager else {
            return DexterAgentHUDPresentation(
                mode: .hidden,
                taskName: "",
                operationLabel: "",
                progressFraction: nil,
                progressCaption: nil,
                openClawStatusLine: nil,
                verificationResultLabel: nil,
                failureHeadline: nil,
                failureDetail: nil,
                canOfferAlwaysAllow: false
            )
        }
        return DexterAgentHUDResolver.resolve(
            companionManager: companionManager,
            holdsTerminalResult: holdsTerminalResult
        )
    }

    func dismissTerminalCard() {
        holdsTerminalResultUntil = nil
        lastTerminalExecutionIdentifier = nil
    }

    private func syncTerminalHoldState() {
        guard let companionManager else { return }
        guard let snapshot = companionManager.dexterRuntimeUIStateStore.activeExecutionSnapshot else {
            if !holdsTerminalResult {
                holdsTerminalResultUntil = nil
            }
            return
        }

        if snapshot.currentPhase.isTerminal {
            if lastTerminalExecutionIdentifier != snapshot.executionIdentifier {
                lastTerminalExecutionIdentifier = snapshot.executionIdentifier
                holdsTerminalResultUntil = Date().addingTimeInterval(8)
            }
        } else {
            lastTerminalExecutionIdentifier = nil
            holdsTerminalResultUntil = nil
        }
    }
}
