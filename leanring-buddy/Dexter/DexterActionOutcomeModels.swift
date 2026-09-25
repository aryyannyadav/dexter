//
//  DexterActionOutcomeModels.swift
//  leanring-buddy
//

import Foundation

/// Observable end state Dexter checks after execution (not LLM/runtime acknowledgement).
enum DexterExpectedOutcome: String, Equatable {
    case applicationRunning
    case applicationNotRunning
    case applicationFrontmost
    case windowVisible
    case textAppeared
    case screenChanged
    case elementStateChanged
    case fileCreated
    case fileChanged
    case unknown
}

/// How Dexter observes whether an action achieved its expected outcome.
enum DexterActionVerificationStrategyKind: String, Equatable {
    case applicationState
    case windowState
    case screenObservation
    case uiObservation
    case fileObservation
    case browserState
    case commandOutput
    case unavailable
}

struct DexterActionResult: Equatable {
    let status: DexterActionResultStatus
    let actionIdentifier: UUID
    let actionType: DexterActionType
    let targetSummary: String?
    let runtimeExecutionIdentifier: String?
    let verificationStatus: DexterActionVerificationStatus?
    let message: String
    let observedStateDescription: String?
    let recordedAt: Date

    static func fromTurnRecord(_ turnRecord: DexterActionTurnRecord, action: DexterAction) -> DexterActionResult {
        DexterActionResult(
            status: turnRecord.resultStatus,
            actionIdentifier: turnRecord.actionIdentifier,
            actionType: action.type,
            targetSummary: turnRecord.targetSummary,
            runtimeExecutionIdentifier: turnRecord.runtimeExecutionIdentifier,
            verificationStatus: turnRecord.verificationStatus,
            message: turnRecord.userFacingExplanation,
            observedStateDescription: nil,
            recordedAt: turnRecord.endedAt ?? turnRecord.startedAt
        )
    }
}

enum DexterActionOutcomePlanner {
    static func expectedOutcome(for actionType: DexterActionType) -> DexterExpectedOutcome {
        switch actionType {
        case .openApplication:
            return .applicationRunning
        case .quitApplication:
            return .applicationNotRunning
        case .focusApplication:
            return .applicationFrontmost
        case .click, .scroll:
            return .screenChanged
        case .typeText:
            return .textAppeared
        case .fileOperation:
            return .fileChanged
        default:
            return .unknown
        }
    }

    static func verificationStrategy(for actionType: DexterActionType) -> DexterActionVerificationStrategyKind {
        switch actionType {
        case .openApplication, .quitApplication, .focusApplication, .listRunningApplications:
            return .applicationState
        case .click, .scroll, .select:
            return .uiObservation
        case .typeText, .keyboardShortcut:
            return .uiObservation
        case .openURL, .navigate:
            return .browserState
        case .fileOperation:
            return .fileObservation
        case .terminalOperation:
            return .commandOutput
        case .inspectScreen, .explainContent:
            return .screenObservation
        default:
            return .unavailable
        }
    }

    static func lifecycleMetadataParameters(
        for actionType: DexterActionType,
        resolvedApplicationReference: DexterApplicationReference
    ) -> [String: String] {
        var parameters: [String: String] = [
            "applicationName": resolvedApplicationReference.displayName,
            "expectedOutcome": expectedOutcome(for: actionType).rawValue,
            "verificationStrategy": verificationStrategy(for: actionType).rawValue,
        ]
        if let bundleIdentifier = resolvedApplicationReference.bundleIdentifier {
            parameters["bundleIdentifier"] = bundleIdentifier
        }
        parameters["openClawApplicationToken"] = resolvedApplicationReference.openClawApplicationToken
        return parameters
    }
}

enum DexterActionBoundedVerificationPolicy {
    static let lifecycleMaxObservationAttempts = 4
    static let lifecycleRetryDelayNanoseconds: UInt64 = 200_000_000

    static func maxObservationAttempts(for action: DexterAction) -> Int {
        switch action.type {
        case .openApplication, .focusApplication, .quitApplication:
            return lifecycleMaxObservationAttempts
        default:
            return 1
        }
    }

    static func shouldRetryObservation(
        action: DexterAction,
        verificationOutcome: ActionVerificationOutcome,
        attemptIndex: Int,
        maxAttempts: Int
    ) -> Bool {
        guard attemptIndex < maxAttempts else { return false }
        guard verificationOutcome.status == .failed else { return false }

        switch action.type {
        case .quitApplication:
            return true
        case .openApplication, .focusApplication:
            return true
        default:
            return false
        }
    }
}
