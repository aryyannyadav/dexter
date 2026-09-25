//
//  DexterDeveloperModeSettings.swift
//  leanring-buddy
//

import Foundation

enum DexterDeveloperModeSettings {
    private static let userDefaultsKey = "dexter.developerModeEnabled"

    static var isDeveloperModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    static func setDeveloperModeEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: userDefaultsKey)
    }
}
