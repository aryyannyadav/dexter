//
//  DexterComputerControlAuthorizationScope.swift
//  leanring-buddy
//

import Foundation

/// Actions that share one session-level “computer control” approval (OpenClaw lifecycle + basic UI).
enum DexterComputerControlAuthorizationScope {
    static func actionQualifiesForSessionReuse(_ action: DexterAction) -> Bool {
        switch action.type {
        case .openApplication, .focusApplication, .quitApplication:
            return true
        case .click:
            return true
        case .openURL, .navigate:
            return action.parameters["browserAction"] != nil
        case .inspectScreen, .explainContent, .listRunningApplications,
             .typeText, .keyboardShortcut, .select, .scroll, .runTask,
             .fileOperation, .terminalOperation:
            return false
        }
    }
}
