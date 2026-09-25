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
        case .openApplication, .focusApplication, .openURL, .scroll, .navigate:
            return true
        case .inspectScreen, .explainContent, .listRunningApplications, .click, .typeText, .keyboardShortcut, .select, .runTask, .quitApplication,
             .fileOperation, .terminalOperation:
            return false
        }
    }
}
