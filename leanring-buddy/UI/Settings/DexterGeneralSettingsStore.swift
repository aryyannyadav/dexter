//
//  DexterGeneralSettingsStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterGeneralSettingsStore: ObservableObject {
    static let shared = DexterGeneralSettingsStore()

    @Published var openHomeWhenDexterLaunches: Bool {
        didSet {
            UserDefaults.standard.set(openHomeWhenDexterLaunches, forKey: openHomeWhenLaunchKey)
        }
    }

    private let openHomeWhenLaunchKey = "dexter.general.openHomeWhenLaunch"

    private init() {
        if UserDefaults.standard.object(forKey: openHomeWhenLaunchKey) == nil {
            openHomeWhenDexterLaunches = true
        } else {
            openHomeWhenDexterLaunches = UserDefaults.standard.bool(forKey: openHomeWhenLaunchKey)
        }
    }
}
