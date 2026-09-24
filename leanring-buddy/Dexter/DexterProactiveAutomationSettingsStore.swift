//
//  DexterProactiveAutomationSettingsStore.swift
//  leanring-buddy
//

import Foundation

protocol DexterProactiveAutomationSettingsStore: AnyObject {
    var automationRegistrations: [DexterProactiveAutomationRegistration] { get set }
}

final class UserDefaultsDexterProactiveAutomationSettingsStore: DexterProactiveAutomationSettingsStore {
    private enum Keys {
        static let automationRegistrations = "dexter.proactive.automationRegistrations"
    }

    var automationRegistrations: [DexterProactiveAutomationRegistration] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.automationRegistrations) else {
                return DexterProactiveAutomationRegistry.defaultRegistrations()
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([DexterProactiveAutomationRegistration].self, from: data))
                ?? DexterProactiveAutomationRegistry.defaultRegistrations()
        }
        set {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Keys.automationRegistrations)
        }
    }
}

final class InMemoryDexterProactiveAutomationSettingsStore: DexterProactiveAutomationSettingsStore {
    var automationRegistrations: [DexterProactiveAutomationRegistration]

    init(automationRegistrations: [DexterProactiveAutomationRegistration] = DexterProactiveAutomationRegistry.defaultRegistrations()) {
        self.automationRegistrations = automationRegistrations
    }
}
