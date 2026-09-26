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
    /// Dexter user authorization for ordinary computer control (persisted via `DexterComputerControlAuthorization`).
    var isComputerControlAuthorizedForSession: Bool { get set }
}

final class InMemoryDexterActionPermissionSettingsStore: DexterActionPermissionSettingsStore {
    var currentSettings: DexterActionPermissionSettings
    var isComputerControlAuthorizedForSession: Bool = false

    init(currentSettings: DexterActionPermissionSettings = .default) {
        self.currentSettings = currentSettings
    }
}

final class UserDefaultsDexterActionPermissionSettingsStore: DexterActionPermissionSettingsStore {
    private let userDefaults: UserDefaults
    private let autoApproveLowRiskActionsKey = "dexter.actionPermission.autoApproveLowRiskActions"
    private var ephemeralComputerControlAuthorization = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        ephemeralComputerControlAuthorization = userDefaults.bool(
            forKey: DexterComputerControlAuthorization.persistedUserAuthorizationKey
        )
    }

    var isComputerControlAuthorizedForSession: Bool {
        get {
            ephemeralComputerControlAuthorization
                || userDefaults.bool(forKey: DexterComputerControlAuthorization.persistedUserAuthorizationKey)
        }
        set {
            ephemeralComputerControlAuthorization = newValue
            userDefaults.set(newValue, forKey: DexterComputerControlAuthorization.persistedUserAuthorizationKey)
        }
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
