//
//  DexterModelSelfGrantDefense.swift
//  leanring-buddy
//

import Foundation

/// Model output cannot grant Dexter permissions or confirmations.
enum DexterModelSelfGrantDefense {
    private static let forbiddenParameterKeys = [
        "grantpermission",
        "grant_permission",
        "bypassconfirmation",
        "bypass_confirmation",
        "autoapprove",
        "auto_approve",
        "selfgrant",
        "self_grant",
        "dexterpermissionlevel",
        "emergencystopoverride"
    ]

    static func actionAttemptsModelSelfGrant(_ action: DexterAction) -> Bool {
        for (key, value) in action.parameters {
            let normalizedKey = key.lowercased().replacingOccurrences(of: "-", with: "_")
            if forbiddenParameterKeys.contains(normalizedKey) {
                return true
            }
            let loweredValue = value.lowercased()
            if loweredValue.contains("grant permission")
                || loweredValue.contains("bypass confirmation")
                || loweredValue.contains("auto approve") {
                return true
            }
        }
        return false
    }

    static func confirmationGrantIsUserOriginated(
        grant: DexterActionConfirmationGrant?,
        action: DexterAction
    ) -> Bool {
        guard let grant else { return false }
        return grant.actionId == action.id
    }
}
