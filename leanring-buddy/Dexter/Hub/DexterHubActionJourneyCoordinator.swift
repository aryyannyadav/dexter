//
//  DexterHubActionJourneyCoordinator.swift
//  leanring-buddy
//
//  Sequences Hub action proposal beats before permission (presentation only).
//

import Foundation

@MainActor
final class DexterHubActionJourneyCoordinator {
    private weak var eventBridge: DexterHubEventBridge?
    private var proposalSequenceTask: Task<Void, Never>?
    private var proposalCompletedActionIdentifiers = Set<String>()
    private var activeExecutionIdentifier: UUID?

    func attach(eventBridge: DexterHubEventBridge) {
        self.eventBridge = eventBridge
    }

    func resetForNewExecution(_ executionIdentifier: UUID?) {
        if let executionIdentifier, executionIdentifier != activeExecutionIdentifier {
            proposalSequenceTask?.cancel()
            proposalCompletedActionIdentifiers.removeAll()
            activeExecutionIdentifier = executionIdentifier
        }
        if executionIdentifier == nil {
            proposalSequenceTask?.cancel()
            proposalCompletedActionIdentifiers.removeAll()
            activeExecutionIdentifier = nil
        }
    }

    func publishMappedEvent(
        _ mapped: DexterHubEventMapper.MappedEvent,
        publishImmediately: @escaping (DexterHubEventMapper.MappedEvent) -> Void
    ) {
        switch mapped {
        case .permission(let title, let subtitle, let actionIdentifier, let actionDescription):
            guard !proposalCompletedActionIdentifiers.contains(actionIdentifier) else {
                publishImmediately(mapped)
                return
            }

            proposalSequenceTask?.cancel()
            proposalSequenceTask = Task { @MainActor [weak self] in
                self?.eventBridge?.broadcastActionProposalCanDo(actionDescription: actionDescription)
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard !Task.isCancelled else { return }
                self?.eventBridge?.broadcastActionProposalWantMeTo(actionDescription: actionDescription)
                try? await Task.sleep(nanoseconds: 380_000_000)
                guard !Task.isCancelled else { return }
                self?.proposalCompletedActionIdentifiers.insert(actionIdentifier)
                publishImmediately(
                    .permission(
                        title: title,
                        subtitle: subtitle,
                        actionIdentifier: actionIdentifier,
                        actionDescription: actionDescription
                    )
                )
            }
        default:
            publishImmediately(mapped)
        }
    }
}
