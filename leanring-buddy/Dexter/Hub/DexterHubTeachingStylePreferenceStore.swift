//
//  DexterHubTeachingStylePreferenceStore.swift
//
//  Optional Hub-selected explanation depth (maps to existing DexterTeachingStyle).
//

import Foundation

enum DexterHubTeachingStylePreferenceStore {
    private static let userDefaultsKey = "DexterHubPreferredTeachingStyle"

    static func preferredTeachingStyle() -> DexterTeachingStyle? {
        guard let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey) else { return nil }
        return DexterTeachingStyle(rawValue: rawValue)
    }

    static func setPreferredTeachingStyle(_ teachingStyle: DexterTeachingStyle?) {
        if let teachingStyle {
            UserDefaults.standard.set(teachingStyle.rawValue, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }

    static func applyHubStyleIdentifier(_ hubStyleIdentifier: String) {
        let mapped = mapHubStyleIdentifier(hubStyleIdentifier)
        setPreferredTeachingStyle(mapped)
    }

    static func mapHubStyleIdentifier(_ hubStyleIdentifier: String) -> DexterTeachingStyle? {
        switch hubStyleIdentifier.lowercased() {
        case "eli5":
            return .eli5
        case "simple", "beginner":
            return .beginner
        case "normal", "standard":
            return .standard
        case "technical":
            return .standard
        case "expert":
            return .expert
        default:
            return nil
        }
    }
}
