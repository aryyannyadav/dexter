//
//  DexterOnboardingState.swift
//  leanring-buddy
//

import Foundation

enum DexterOnboardingState: String, Equatable {
    case notStarted
    case inProgress
    case completed
    case skipped
}

enum DexterOnboardingStateStore {
    private static let stateKey = "dexterProductOnboardingState"

    static func currentState(hasLegacyCompletedFlag: Bool) -> DexterOnboardingState {
        if hasLegacyCompletedFlag {
            return .completed
        }
        if let raw = UserDefaults.standard.string(forKey: stateKey),
           let stored = DexterOnboardingState(rawValue: raw) {
            return stored
        }
        return .notStarted
    }

    static func shouldPresentProductOnboarding(
        hasLegacyCompletedFlag: Bool,
        existingProfileCount: Int
    ) -> Bool {
        let state = currentState(hasLegacyCompletedFlag: hasLegacyCompletedFlag)
        switch state {
        case .completed, .skipped:
            return false
        case .notStarted, .inProgress:
            if existingProfileCount > 0 && !hasLegacyCompletedFlag {
                recordCompleted()
                return false
            }
            return !hasLegacyCompletedFlag
        }
    }

    static func recordInProgress() {
        UserDefaults.standard.set(DexterOnboardingState.inProgress.rawValue, forKey: stateKey)
    }

    static func recordCompleted() {
        UserDefaults.standard.set(DexterOnboardingState.completed.rawValue, forKey: stateKey)
    }

    static func recordSkipped() {
        UserDefaults.standard.set(DexterOnboardingState.skipped.rawValue, forKey: stateKey)
    }
}
