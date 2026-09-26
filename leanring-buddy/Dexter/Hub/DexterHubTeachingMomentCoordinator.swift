//
//  DexterHubTeachingMomentCoordinator.swift
//
//  Keeps Hub teaching presentation aligned with session store updates.
//

import Combine
import Foundation

@MainActor
final class DexterHubTeachingMomentCoordinator {
    private var cancellables = Set<AnyCancellable>()

    func install(teachingSessionPublisher: AnyPublisher<DexterTeachingSession?, Never>) {
        teachingSessionPublisher
            .removeDuplicates()
            .sink { session in
                DexterHubTeachingMomentReporter.reportTeachingSessionPhaseChanged(session)
            }
            .store(in: &cancellables)
    }
}
