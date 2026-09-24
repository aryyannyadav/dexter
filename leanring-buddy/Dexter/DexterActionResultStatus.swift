//
//  DexterActionResultStatus.swift
//  leanring-buddy
//

import Foundation

/// User-facing action lifecycle status (single source of truth for UI/voice copy).
enum DexterActionResultStatus: String, Equatable {
    case proposed
    case awaitingPermission
    case executing
    case succeeded
    case partiallyVerified
    case verificationFailed
    case refused
    case failed
    case cancelled
    case unavailable
}

struct DexterActionTurnRecord: Equatable {
    let actionIdentifier: UUID
    let intentSummary: String
    let targetSummary: String?
    let runtimeName: String?
    let runtimeExecutionIdentifier: String?
    let startedAt: Date
    let endedAt: Date?
    let resultStatus: DexterActionResultStatus
    let verificationStatus: DexterActionVerificationStatus?
    let userFacingExplanation: String
}

enum DexterActionTurnRecordBuilder {
    static func build(
        action: DexterAction,
        runtimeName: String?,
        runtimeExecutionIdentifier: String?,
        verificationReport: DexterActionVerificationReport?,
        spokenSummary: String
    ) -> DexterActionTurnRecord {
        let resultStatus = mapResultStatus(action: action, verificationReport: verificationReport)
        let targetSummary = action.parameters["applicationName"]
            ?? action.parameters["url"]
            ?? action.parameters["label"]

        return DexterActionTurnRecord(
            actionIdentifier: action.id,
            intentSummary: action.type.rawValue,
            targetSummary: targetSummary,
            runtimeName: runtimeName,
            runtimeExecutionIdentifier: runtimeExecutionIdentifier,
            startedAt: action.proposedAt,
            endedAt: action.updatedAt,
            resultStatus: resultStatus,
            verificationStatus: verificationReport?.status,
            userFacingExplanation: spokenSummary
        )
    }

    private static func mapResultStatus(
        action: DexterAction,
        verificationReport: DexterActionVerificationReport?
    ) -> DexterActionResultStatus {
        switch action.state {
        case .proposed:
            return .proposed
        case .awaitingConfirmation:
            return .awaitingPermission
        case .approved, .executing:
            return .executing
        case .cancelled:
            return .cancelled
        case .failed:
            return .failed
        case .verificationFailed:
            if verificationReport?.status == .partiallyVerified {
                return .partiallyVerified
            }
            return .verificationFailed
        case .completed:
            if verificationReport?.status == .partiallyVerified {
                return .partiallyVerified
            }
            return .succeeded
        }
    }
}
