//
//  DexterCursorVisibilityPreferences.swift
//  leanring-buddy
//

import Foundation

enum DexterCursorVisibilityPreferences {
    private static let dexterCursorEnabledUserDefaultsKey = "isDexterCursorEnabled"
    private static let legacyClickyCursorEnabledUserDefaultsKey = "isClickyCursorEnabled"

    static func readIsCursorOverlayEnabled(defaultValue: Bool = true) -> Bool {
        if UserDefaults.standard.object(forKey: dexterCursorEnabledUserDefaultsKey) != nil {
            return UserDefaults.standard.bool(forKey: dexterCursorEnabledUserDefaultsKey)
        }
        if UserDefaults.standard.object(forKey: legacyClickyCursorEnabledUserDefaultsKey) == nil {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: legacyClickyCursorEnabledUserDefaultsKey)
    }

    static func writeIsCursorOverlayEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: dexterCursorEnabledUserDefaultsKey)
    }
}
