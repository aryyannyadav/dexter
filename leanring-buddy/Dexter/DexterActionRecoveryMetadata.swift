//
//  DexterActionRecoveryMetadata.swift
//  leanring-buddy
//
//  Semantic before/intended/after state for state-changing actions (no coordinate replay).
//

import Foundation

struct DexterActionSemanticState: Equatable, Codable {
    let summary: String
    let applicationName: String?
    let applicationBundleIdentifier: String?
    let windowTitle: String?
    let browserPageURL: String?
    let browserPageTitle: String?

    static func from(observation: DexterActionObservationSnapshot) -> DexterActionSemanticState {
        let applicationName = observation.activeApplicationLocalizedName?.nonEmptyTrimmedValue
        let windowTitle = observation.activeWindowTitle?.nonEmptyTrimmedValue
        let browserURL = observation.browserState.url?.nonEmptyTrimmedValue
        let browserTitle = observation.browserState.title?.nonEmptyTrimmedValue

        var summaryParts: [String] = []
        if let applicationName {
            summaryParts.append("App: \(applicationName)")
        }
        if let windowTitle {
            summaryParts.append("Window: \(windowTitle)")
        }
        if let browserURL {
            summaryParts.append("URL: \(browserURL)")
        } else if let browserTitle {
            summaryParts.append("Page: \(browserTitle)")
        }

        let summary = summaryParts.isEmpty ? "No environment snapshot available." : summaryParts.joined(separator: " · ")

        return DexterActionSemanticState(
            summary: summary,
            applicationName: applicationName,
            applicationBundleIdentifier: observation.activeApplicationBundleIdentifier?.nonEmptyTrimmedValue,
            windowTitle: windowTitle,
            browserPageURL: browserURL,
            browserPageTitle: browserTitle
        )
    }
}

enum DexterActionRollbackStrategy: Equatable, Codable {
    case none
    case focusPreviousApplication(applicationName: String)
    case openPreviousBrowserURL(url: String, verificationHint: String)
    case notSupported(reason: String)
}

struct DexterActionRecoveryProfile: Equatable {
    let beforeState: DexterActionSemanticState?
    let intendedState: DexterActionSemanticState
    let afterState: DexterActionSemanticState?
    let reversible: Bool
    let rollbackStrategy: DexterActionRollbackStrategy
}

struct DexterActionRecoveryMetadata: Equatable, Codable {
    let actionIdentifier: UUID
    let actionTypeRawValue: String
    let beforeState: DexterActionSemanticState?
    let intendedState: DexterActionSemanticState
    let afterState: DexterActionSemanticState?
    let reversible: Bool
    let rollbackStrategy: DexterActionRollbackStrategy
    let recordedAt: Date

    var actionType: DexterActionType? {
        DexterActionType(rawValue: actionTypeRawValue)
    }
}

enum DexterActionRecoveryCopy {
    static func irreversibilityWarning(for profile: DexterActionRecoveryProfile) -> String? {
        guard !profile.reversible else { return nil }
        switch profile.rollbackStrategy {
        case .notSupported(let reason):
            return "This change cannot be undone automatically. \(reason) Dexter will not claim rollback capability."
        case .none:
            return "This change cannot be undone automatically. Dexter will not claim rollback capability."
        case .focusPreviousApplication, .openPreviousBrowserURL:
            return nil
        }
    }

    static func undoUnavailableMessage(for metadata: DexterActionRecoveryMetadata?) -> String {
        if metadata == nil {
            return "There is no recent Dexter action with recovery metadata to undo."
        }
        if metadata?.reversible == false {
            return "The last action cannot be undone safely. Dexter did not record a rollback strategy for it."
        }
        return "Undo is not available for the last action right now."
    }
}

enum DexterActionRecoveryMetadataBuilder {
    static func recoveryProfile(
        for action: DexterAction,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot? = nil
    ) -> DexterActionRecoveryProfile {
        let beforeState = meaningfulBeforeState(from: observationBefore)
        let intendedState = intendedState(for: action, observationBefore: observationBefore)
        let afterState = observationAfter.map { DexterActionSemanticState.from(observation: $0) }
        let reversible = isReversible(action: action)
        let rollbackStrategy = rollbackStrategy(
            for: action,
            beforeState: beforeState,
            reversible: reversible
        )

        return DexterActionRecoveryProfile(
            beforeState: beforeState,
            intendedState: intendedState,
            afterState: afterState,
            reversible: reversible,
            rollbackStrategy: rollbackStrategy
        )
    }

    static func build(
        action: DexterAction,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot?
    ) -> DexterActionRecoveryMetadata {
        let profile = recoveryProfile(
            for: action,
            observationBefore: observationBefore,
            observationAfter: observationAfter
        )

        return DexterActionRecoveryMetadata(
            actionIdentifier: action.id,
            actionTypeRawValue: action.type.rawValue,
            beforeState: profile.beforeState,
            intendedState: profile.intendedState,
            afterState: profile.afterState,
            reversible: profile.reversible,
            rollbackStrategy: profile.rollbackStrategy,
            recordedAt: Date()
        )
    }

    static func isReversible(action: DexterAction) -> Bool {
        switch action.type {
        case .openApplication, .focusApplication:
            return true
        case .openURL, .navigate:
            return action.parameters["browserAction"] != nil
                || action.parameters["url"]?.nonEmptyTrimmedValue != nil
        case .scroll:
            return false
        case .inspectScreen, .explainContent, .listRunningApplications, .click, .typeText, .keyboardShortcut, .select,
             .runTask, .quitApplication, .fileOperation, .terminalOperation:
            return false
        }
    }

    private static func meaningfulBeforeState(
        from observation: DexterActionObservationSnapshot
    ) -> DexterActionSemanticState? {
        let state = DexterActionSemanticState.from(observation: observation)
        if state.applicationName == nil
            && state.windowTitle == nil
            && state.browserPageURL == nil
            && state.browserPageTitle == nil {
            return nil
        }
        return state
    }

    private static func intendedState(
        for action: DexterAction,
        observationBefore: DexterActionObservationSnapshot
    ) -> DexterActionSemanticState {
        switch action.type {
        case .openApplication, .focusApplication:
            let applicationName = action.parameters["applicationName"]?.nonEmptyTrimmedValue ?? "target application"
            return DexterActionSemanticState(
                summary: "Frontmost app becomes \(applicationName).",
                applicationName: applicationName,
                applicationBundleIdentifier: nil,
                windowTitle: nil,
                browserPageURL: nil,
                browserPageTitle: nil
            )

        case .openURL, .navigate:
            let url = action.parameters["url"]?.nonEmptyTrimmedValue
                ?? action.parameters["destination"]?.nonEmptyTrimmedValue
            let hint = action.parameters["verificationHint"]?.nonEmptyTrimmedValue ?? url ?? "browser destination"
            return DexterActionSemanticState(
                summary: "Browser shows \(hint).",
                applicationName: observationBefore.activeApplicationLocalizedName,
                applicationBundleIdentifier: observationBefore.activeApplicationBundleIdentifier,
                windowTitle: nil,
                browserPageURL: url,
                browserPageTitle: hint
            )

        case .typeText:
            return DexterActionSemanticState(
                summary: "Focused field contains typed text.",
                applicationName: observationBefore.activeApplicationLocalizedName,
                applicationBundleIdentifier: observationBefore.activeApplicationBundleIdentifier,
                windowTitle: observationBefore.activeWindowTitle,
                browserPageURL: nil,
                browserPageTitle: nil
            )

        case .click:
            return DexterActionSemanticState(
                summary: "UI element at pointer receives a click.",
                applicationName: observationBefore.activeApplicationLocalizedName,
                applicationBundleIdentifier: observationBefore.activeApplicationBundleIdentifier,
                windowTitle: observationBefore.activeWindowTitle,
                browserPageURL: nil,
                browserPageTitle: nil
            )

        case .fileOperation:
            return DexterActionSemanticState(
                summary: "Filesystem change at approved path.",
                applicationName: nil,
                applicationBundleIdentifier: nil,
                windowTitle: nil,
                browserPageURL: nil,
                browserPageTitle: nil
            )

        case .terminalOperation:
            return DexterActionSemanticState(
                summary: "Terminal command output changes.",
                applicationName: observationBefore.activeApplicationLocalizedName,
                applicationBundleIdentifier: nil,
                windowTitle: nil,
                browserPageURL: nil,
                browserPageTitle: nil
            )

        default:
            return DexterActionSemanticState(
                summary: action.humanReadableDescription,
                applicationName: observationBefore.activeApplicationLocalizedName,
                applicationBundleIdentifier: observationBefore.activeApplicationBundleIdentifier,
                windowTitle: observationBefore.activeWindowTitle,
                browserPageURL: observationBefore.browserState.url,
                browserPageTitle: observationBefore.browserState.title
            )
        }
    }

    private static func rollbackStrategy(
        for action: DexterAction,
        beforeState: DexterActionSemanticState?,
        reversible: Bool
    ) -> DexterActionRollbackStrategy {
        guard reversible else {
            return irreversibleRollbackReason(for: action)
        }

        switch action.type {
        case .openApplication, .focusApplication:
            if let previousApplicationName = beforeState?.applicationName?.nonEmptyTrimmedValue {
                return .focusPreviousApplication(applicationName: previousApplicationName)
            }
            return .notSupported(reason: "Dexter did not capture which app was frontmost before this action.")

        case .openURL, .navigate:
            if let previousURL = beforeState?.browserPageURL?.nonEmptyTrimmedValue {
                let hint = beforeState?.browserPageTitle ?? previousURL
                return .openPreviousBrowserURL(url: previousURL, verificationHint: hint)
            }
            if let previousApplicationName = beforeState?.applicationName?.nonEmptyTrimmedValue {
                return .focusPreviousApplication(applicationName: previousApplicationName)
            }
            return .notSupported(reason: "Dexter did not capture a previous browser URL to restore.")

        default:
            return .none
        }
    }

    private static func irreversibleRollbackReason(for action: DexterAction) -> DexterActionRollbackStrategy {
        switch action.type {
        case .click:
            return .notSupported(reason: "Pointer clicks cannot be reversed without guessing UI coordinates.")
        case .typeText:
            return .notSupported(reason: "Typed text cannot be reliably reversed.")
        case .keyboardShortcut:
            return .notSupported(reason: "Keyboard shortcuts may trigger destructive or unknown effects.")
        case .fileOperation:
            return .notSupported(reason: "File changes may be destructive.")
        case .terminalOperation:
            return .notSupported(reason: "Shell commands may be destructive.")
        case .runTask:
            return .notSupported(reason: "Agent tasks may perform multi-step irreversible work.")
        case .quitApplication:
            return .notSupported(reason: "Quitting an application cannot be safely auto-reversed.")
        default:
            return .notSupported(reason: "This action type does not support automatic rollback.")
        }
    }
}
