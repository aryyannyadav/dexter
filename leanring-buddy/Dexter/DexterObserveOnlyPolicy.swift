//
//  DexterObserveOnlyPolicy.swift
//  leanring-buddy
//

import Foundation

/// When false, Dexter explains only and never runs the action execution pipeline.
enum DexterObserveOnlyPolicy {
    private static let userDefaultsKey = "dexterAutonomousComputerControlEnabled"

    static var isAutonomousComputerControlEnabled: Bool {
        if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    static func setAutonomousComputerControlEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
    }
}
