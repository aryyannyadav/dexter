//
//  DexterExecutionStateMachine.swift
//  leanring-buddy
//

import Foundation

/// Canonical execution phases for Dexter invocations (user → response).
enum DexterExecutionPhase: String, Equatable, CaseIterable {
    case received = "RECEIVED"
    case understanding = "UNDERSTANDING"
    case planning = "PLANNING"
    case waitingPermission = "WAITING_PERMISSION"
    case executing = "EXECUTING"
    case verifying = "VERIFYING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}

struct DexterExecutionErrorInfo: Equatable {
    let code: String
    let message: String
}

struct DexterExecutionMachineSnapshot: Equatable, Identifiable {
    let executionIdentifier: UUID
    let actionIdentifier: UUID
    let parentTaskIdentifier: UUID?
    let currentPhase: DexterExecutionPhase
    let progressSummary: String?
    let receivedAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let stepCount: Int
    let actionBudget: Int
    let toolBudget: Int
    let actionsConsumed: Int
    let toolsConsumed: Int
    let isCancellationRequested: Bool
    let timeoutSeconds: TimeInterval?
    let errorInfo: DexterExecutionErrorInfo?
    let verificationStatus: DexterActionVerificationStatus?

    var id: UUID { executionIdentifier }
}

enum DexterExecutionStateMachineLog {
    static func log(executionIdentifier: UUID, phase: DexterExecutionPhase, detail: String) {
        print("[DEXTER][EXECUTION] id=\(executionIdentifier.uuidString.prefix(8)) phase=\(phase.rawValue) \(detail)")
    }
}

enum DexterExecutionStateMachineTransitionRules {
    static func canTransition(from currentPhase: DexterExecutionPhase, to nextPhase: DexterExecutionPhase) -> Bool {
        if currentPhase == nextPhase {
            return true
        }
        if currentPhase.isTerminal {
            return false
        }

        switch currentPhase {
        case .received:
            return nextPhase == .understanding || nextPhase == .failed || nextPhase == .cancelled
        case .understanding:
            return nextPhase == .planning || nextPhase == .failed || nextPhase == .cancelled
        case .planning:
            return nextPhase == .waitingPermission
                || nextPhase == .executing
                || nextPhase == .completed
                || nextPhase == .failed
                || nextPhase == .cancelled
        case .waitingPermission:
            return nextPhase == .executing || nextPhase == .failed || nextPhase == .cancelled
        case .executing:
            return nextPhase == .verifying || nextPhase == .failed || nextPhase == .cancelled
        case .verifying:
            return nextPhase == .completed || nextPhase == .failed || nextPhase == .cancelled
        case .completed, .failed, .cancelled:
            return false
        }
    }
}

enum DexterExecutionStateMachineError: Error, Equatable {
    case invalidTransition(from: DexterExecutionPhase, to: DexterExecutionPhase)
    case cancellationRequested
    case actionBudgetExceeded
    case toolBudgetExceeded
    case timedOut
}

/// Mutable execution controller for one action invocation. All pipeline transitions flow through `transition`.
final class DexterExecutionStateMachine {
    private(set) var snapshot: DexterExecutionMachineSnapshot
    var onSnapshotChanged: ((DexterExecutionMachineSnapshot) -> Void)?

    init(
        actionIdentifier: UUID,
        parentTaskIdentifier: UUID? = nil,
        actionBudget: Int = 3,
        toolBudget: Int = 5,
        timeoutSeconds: TimeInterval = 120,
        receivedAt: Date = Date()
    ) {
        let executionIdentifier = UUID()
        snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: executionIdentifier,
            actionIdentifier: actionIdentifier,
            parentTaskIdentifier: parentTaskIdentifier,
            currentPhase: .received,
            progressSummary: "Invocation received.",
            receivedAt: receivedAt,
            updatedAt: receivedAt,
            completedAt: nil,
            stepCount: 0,
            actionBudget: actionBudget,
            toolBudget: toolBudget,
            actionsConsumed: 0,
            toolsConsumed: 0,
            isCancellationRequested: false,
            timeoutSeconds: timeoutSeconds,
            errorInfo: nil,
            verificationStatus: nil
        )
        DexterExecutionStateMachineLog.log(
            executionIdentifier: executionIdentifier,
            phase: .received,
            detail: "action=\(actionIdentifier.uuidString.prefix(8))"
        )
        notifySnapshotChanged()
    }

    func requestCancellation(reason: String = "User cancelled.") {
        snapshot = updatedSnapshot(
            isCancellationRequested: true,
            progressSummary: reason
        )
        notifySnapshotChanged()
    }

    func checkContinuationAllowed() throws {
        if snapshot.isCancellationRequested {
            throw DexterExecutionStateMachineError.cancellationRequested
        }
        if let timeoutSeconds = snapshot.timeoutSeconds {
            let elapsedSeconds = Date().timeIntervalSince(snapshot.receivedAt)
            if elapsedSeconds > timeoutSeconds {
                throw DexterExecutionStateMachineError.timedOut
            }
        }
    }

    func recordActionConsumption() throws {
        let nextConsumed = snapshot.actionsConsumed + 1
        if nextConsumed > snapshot.actionBudget {
            throw DexterExecutionStateMachineError.actionBudgetExceeded
        }
        snapshot = updatedSnapshot(actionsConsumed: nextConsumed)
        notifySnapshotChanged()
    }

    func recordToolConsumption() throws {
        let nextConsumed = snapshot.toolsConsumed + 1
        if nextConsumed > snapshot.toolBudget {
            throw DexterExecutionStateMachineError.toolBudgetExceeded
        }
        snapshot = updatedSnapshot(toolsConsumed: nextConsumed)
        notifySnapshotChanged()
    }

    @discardableResult
    func transition(
        to nextPhase: DexterExecutionPhase,
        progressSummary: String? = nil,
        errorInfo: DexterExecutionErrorInfo? = nil,
        verificationStatus: DexterActionVerificationStatus? = nil
    ) throws -> DexterExecutionMachineSnapshot {
        let currentPhase = snapshot.currentPhase
        guard DexterExecutionStateMachineTransitionRules.canTransition(from: currentPhase, to: nextPhase) else {
            throw DexterExecutionStateMachineError.invalidTransition(from: currentPhase, to: nextPhase)
        }

        let now = Date()
        let completedAt = nextPhase.isTerminal ? now : snapshot.completedAt
        let nextStepCount = snapshot.stepCount + (nextPhase == currentPhase ? 0 : 1)

        snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: snapshot.executionIdentifier,
            actionIdentifier: snapshot.actionIdentifier,
            parentTaskIdentifier: snapshot.parentTaskIdentifier,
            currentPhase: nextPhase,
            progressSummary: progressSummary ?? snapshot.progressSummary,
            receivedAt: snapshot.receivedAt,
            updatedAt: now,
            completedAt: completedAt,
            stepCount: nextStepCount,
            actionBudget: snapshot.actionBudget,
            toolBudget: snapshot.toolBudget,
            actionsConsumed: snapshot.actionsConsumed,
            toolsConsumed: snapshot.toolsConsumed,
            isCancellationRequested: snapshot.isCancellationRequested,
            timeoutSeconds: snapshot.timeoutSeconds,
            errorInfo: errorInfo ?? snapshot.errorInfo,
            verificationStatus: verificationStatus ?? snapshot.verificationStatus
        )

        DexterExecutionStateMachineLog.log(
            executionIdentifier: snapshot.executionIdentifier,
            phase: nextPhase,
            detail: progressSummary ?? ""
        )
        notifySnapshotChanged()
        return snapshot
    }

    private func notifySnapshotChanged() {
        onSnapshotChanged?(snapshot)
    }

    func fail(code: String, message: String) throws {
        try transition(
            to: .failed,
            progressSummary: message,
            errorInfo: DexterExecutionErrorInfo(code: code, message: message)
        )
    }

    func cancel(message: String) throws {
        requestCancellation(reason: message)
        try transition(
            to: .cancelled,
            progressSummary: message,
            errorInfo: DexterExecutionErrorInfo(code: "cancelled", message: message)
        )
    }

    private func updatedSnapshot(
        isCancellationRequested: Bool? = nil,
        progressSummary: String? = nil,
        actionsConsumed: Int? = nil,
        toolsConsumed: Int? = nil
    ) -> DexterExecutionMachineSnapshot {
        DexterExecutionMachineSnapshot(
            executionIdentifier: snapshot.executionIdentifier,
            actionIdentifier: snapshot.actionIdentifier,
            parentTaskIdentifier: snapshot.parentTaskIdentifier,
            currentPhase: snapshot.currentPhase,
            progressSummary: progressSummary ?? snapshot.progressSummary,
            receivedAt: snapshot.receivedAt,
            updatedAt: Date(),
            completedAt: snapshot.completedAt,
            stepCount: snapshot.stepCount,
            actionBudget: snapshot.actionBudget,
            toolBudget: snapshot.toolBudget,
            actionsConsumed: actionsConsumed ?? snapshot.actionsConsumed,
            toolsConsumed: toolsConsumed ?? snapshot.toolsConsumed,
            isCancellationRequested: isCancellationRequested ?? snapshot.isCancellationRequested,
            timeoutSeconds: snapshot.timeoutSeconds,
            errorInfo: snapshot.errorInfo,
            verificationStatus: snapshot.verificationStatus
        )
    }
}

@MainActor
final class DexterExecutionStateMachineRegistry {
    private var machinesByExecutionIdentifier: [UUID: DexterExecutionStateMachine] = [:]
    var onExecutionSnapshotChanged: ((DexterExecutionMachineSnapshot) -> Void)?

    func register(_ stateMachine: DexterExecutionStateMachine) {
        machinesByExecutionIdentifier[stateMachine.snapshot.executionIdentifier] = stateMachine
        stateMachine.onSnapshotChanged = { [weak self] snapshot in
            self?.onExecutionSnapshotChanged?(snapshot)
        }
        onExecutionSnapshotChanged?(stateMachine.snapshot)
    }

    func machine(forExecutionIdentifier executionIdentifier: UUID) -> DexterExecutionStateMachine? {
        machinesByExecutionIdentifier[executionIdentifier]
    }

    func latestSnapshot() -> DexterExecutionMachineSnapshot? {
        machinesByExecutionIdentifier.values
            .map(\.snapshot)
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first
    }

    func requestCancellation(forExecutionIdentifier executionIdentifier: UUID) {
        machinesByExecutionIdentifier[executionIdentifier]?.requestCancellation()
    }
}
