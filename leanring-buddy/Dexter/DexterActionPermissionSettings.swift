//
//  DexterActionPermissionSettings.swift
//  leanring-buddy
//

import Foundation

struct DexterActionPermissionSettings: Equatable {
    /// When true, LOW_RISK actions may run without the confirmation sheet.
    var autoApproveLowRiskActions: Bool

    static let `default` = DexterActionPermissionSettings(autoApproveLowRiskActions: false)
}

protocol DexterActionPermissionSettingsStore: AnyObject {
    var currentSettings: DexterActionPermissionSettings { get set }
}

final class InMemoryDexterActionPermissionSettingsStore: DexterActionPermissionSettingsStore {
    var currentSettings: DexterActionPermissionSettings

    init(currentSettings: DexterActionPermissionSettings = .default) {
        self.currentSettings = currentSettings
    }
}

final class UserDefaultsDexterActionPermissionSettingsStore: DexterActionPermissionSettingsStore {
    private let userDefaults: UserDefaults
    private let autoApproveLowRiskActionsKey = "dexter.actionPermission.autoApproveLowRiskActions"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currentSettings: DexterActionPermissionSettings {
        get {
            DexterActionPermissionSettings(
                autoApproveLowRiskActions: userDefaults.bool(forKey: autoApproveLowRiskActionsKey)
            )
        }
        set {
            userDefaults.set(newValue.autoApproveLowRiskActions, forKey: autoApproveLowRiskActionsKey)
        }
    }
}
