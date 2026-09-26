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
            if action.parameters["browserAction"] != nil { return true }
            return action.parameters["uiDestination"]?.nonEmptyTrimmedValue != nil
        case .typeText, .keyboardShortcut, .scroll:
            return true
        case .inspectScreen, .explainContent, .listRunningApplications,
             .select, .runTask, .fileOperation, .terminalOperation:
            return false
        }
    }
}
