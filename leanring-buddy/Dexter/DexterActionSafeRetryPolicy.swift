//
//  DexterActionSafeRetryPolicy.swift
//  leanring-buddy
//

import Foundation

enum DexterActionSafeRetryPolicy {
    static func canAttemptSafeRetry(for action: DexterAction) -> Bool {
        let resolvedRiskLevel = DexterActionRiskClassifier.resolvedRiskLevel(for: action)
        guard resolvedRiskLevel == .lowRisk else {
            return false
        }

        switch action.type {
        case .openApplication, .openURL, .scroll, .navigate:
            return true
        case .inspectScreen, .explainContent, .click, .typeText, .keyboardShortcut, .select, .runTask:
            return false
        }
    }
}
