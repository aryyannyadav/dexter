//
//  DexterComputerControlAuthorization.swift
//  leanring-buddy
//

import Foundation

/// Dexter user authorization for ordinary computer control (distinct from OpenClaw/node/OS permissions).
enum DexterComputerControlAuthorization {
    static let persistedUserAuthorizationKey = "dexter.computerControl.userAuthorized"

    static func isUserAuthorized(store: DexterActionPermissionSettingsStore) -> Bool {
        store.isComputerControlAuthorizedForSession
    }

    static func grantUserAuthorization(store: DexterActionPermissionSettingsStore) {
        store.isComputerControlAuthorizedForSession = true
        DexterActionDiagnosticLog.permission("computerControl=authorized")
    }

    static func revokeUserAuthorization(store: DexterActionPermissionSettingsStore) {
        store.isComputerControlAuthorizedForSession = false
        DexterActionDiagnosticLog.permission("computerControl=revoked")
    }

    static func authorizationStatusLabel(store: DexterActionPermissionSettingsStore) -> String {
        isUserAuthorized(store: store) ? "Authorized" : "Not authorized"
    }
}
