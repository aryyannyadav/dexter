//
//  DexterExecutionStateMachineTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterExecutionStateMachineTests {
    @Test func receivedTransitions() throws {
        let machine = DexterExecutionStateMachine(actionIdentifier: UUID())
        #expect(machine.snapshot.currentPhase == .received)

        try machine.transition(to: .understanding, progressSummary: "Understanding.")
        #expect(machine.snapshot.currentPhase == .understanding)
        #expect(machine.snapshot.stepCount == 1)

        let machineForFailure = DexterExecutionStateMachine(actionIdentifier: UUID())
        try machineForFailure.fail(code: "test", message: "Failed early.")
        #expect(machineForFailure.snapshot.currentPhase == .failed)

        let machineForCancel = DexterExecutionStateMachine(actionIdentifier: UUID())
        try machineForCancel.cancel(message: "Cancelled early.")
        #expect(machineForCancel.snapshot.currentPhase == .cancelled)
    }

    @Test func understandingTransitions() throws {
        let machine = makeMachine(at: .understanding)
        try machine.transition(to: .planning, progressSummary: "Planning.")
        #expect(machine.snapshot.currentPhase == .planning)

        let failureMachine = makeMachine(at: .understanding)
        try failureMachine.fail(code: "test", message: "Planning failed.")
        #expect(failureMachine.snapshot.currentPhase == .failed)

        let cancelMachine = makeMachine(at: .understanding)
        try cancelMachine.cancel(message: "Cancelled during understanding.")
        #expect(cancelMachine.snapshot.currentPhase == .cancelled)
    }

    @Test func planningTransitions() throws {
        let waitingMachine = makeMachine(at: .planning)
        try waitingMachine.transition(to: .waitingPermission, progressSummary: "Awaiting approval.")
        #expect(waitingMachine.snapshot.currentPhase == .waitingPermission)

        let executingMachine = makeMachine(at: .planning)
        try executingMachine.transition(to: .executing, progressSummary: "Executing.")
        #expect(executingMachine.snapshot.currentPhase == .executing)

        let completedMachine = makeMachine(at: .planning)
        try completedMachine.transition(to: .completed, progressSummary: "Read-only complete.")
        #expect(completedMachine.snapshot.currentPhase == .completed)
        #expect(completedMachine.snapshot.completedAt != nil)

        let failedMachine = makeMachine(at: .planning)
        try failedMachine.fail(code: "denied", message: "Permission denied.")
        #expect(failedMachine.snapshot.currentPhase == .failed)

        let cancelledMachine = makeMachine(at: .planning)
        try cancelledMachine.cancel(message: "Cancelled during planning.")
        #expect(cancelledMachine.snapshot.currentPhase == .cancelled)
    }

    @Test func waitingPermissionTransitions() throws {
        let executingMachine = makeMachine(at: .waitingPermission)
        try executingMachine.transition(to: .executing, progressSummary: "Approved.")
        #expect(executingMachine.snapshot.currentPhase == .executing)

        let failedMachine = makeMachine(at: .waitingPermission)
        try failedMachine.fail(code: "denied", message: "Denied.")
        #expect(failedMachine.snapshot.currentPhase == .failed)

        let cancelledMachine = makeMachine(at: .waitingPermission)
        try cancelledMachine.cancel(message: "Cancelled at permission gate.")
        #expect(cancelledMachine.snapshot.currentPhase == .cancelled)
    }

    @Test func executingTransitions() throws {
        let verifyingMachine = makeMachine(at: .executing)
        try verifyingMachine.transition(to: .verifying, progressSummary: "Verifying.")
        #expect(verifyingMachine.snapshot.currentPhase == .verifying)

        let failedMachine = makeMachine(at: .executing)
        try failedMachine.fail(code: "runtime", message: "Runtime failed.")
        #expect(failedMachine.snapshot.currentPhase == .failed)

        let cancelledMachine = makeMachine(at: .executing)
        try cancelledMachine.cancel(message: "Cancelled during execution.")
        #expect(cancelledMachine.snapshot.currentPhase == .cancelled)
    }

    @Test func verifyingTransitions() throws {
        let completedMachine = makeMachine(at: .verifying)
        try completedMachine.transition(
            to: .completed,
            progressSummary: "Verified.",
            verificationStatus: .verified
        )
        #expect(completedMachine.snapshot.currentPhase == .completed)
        #expect(completedMachine.snapshot.verificationStatus == .verified)

        let failedMachine = makeMachine(at: .verifying)
        try failedMachine.fail(code: "verify", message: "Verification failed.")
        #expect(failedMachine.snapshot.currentPhase == .failed)

        let cancelledMachine = makeMachine(at: .verifying)
        try cancelledMachine.cancel(message: "Cancelled during verification.")
        #expect(cancelledMachine.snapshot.currentPhase == .cancelled)
    }

    @Test func terminalPhasesRejectFurtherTransitions() throws {
        let completedMachine = makeMachine(at: .verifying)
        try completedMachine.transition(to: .completed, progressSummary: "Done.")
        #expect(
            throws: DexterExecutionStateMachineError.invalidTransition(from: .completed, to: .executing)
        ) {
            try completedMachine.transition(to: .executing, progressSummary: "Should not run.")
        }
    }

    @Test func invalidTransitionsAreRejected() throws {
        let machine = DexterExecutionStateMachine(actionIdentifier: UUID())
        #expect(
            throws: DexterExecutionStateMachineError.invalidTransition(from: .received, to: .executing)
        ) {
            try machine.transition(to: .executing, progressSummary: "Invalid jump.")
        }
    }

    @Test func budgetsAndTimeoutAreEnforced() throws {
        let machine = DexterExecutionStateMachine(
            actionIdentifier: UUID(),
            actionBudget: 1,
            toolBudget: 1,
            timeoutSeconds: 60
        )
        try machine.recordActionConsumption()
        #expect(throws: DexterExecutionStateMachineError.actionBudgetExceeded) {
            try machine.recordActionConsumption()
        }

        let toolMachine = DexterExecutionStateMachine(actionIdentifier: UUID(), toolBudget: 1)
        try toolMachine.recordToolConsumption()
        #expect(throws: DexterExecutionStateMachineError.toolBudgetExceeded) {
            try toolMachine.recordToolConsumption()
        }
    }

    @Test func cancellationRequestBlocksContinuation() throws {
        let machine = DexterExecutionStateMachine(actionIdentifier: UUID())
        machine.requestCancellation()
        #expect(throws: DexterExecutionStateMachineError.cancellationRequested) {
            try machine.checkContinuationAllowed()
        }
    }

    @Test @MainActor func registryStoresLatestSnapshot() throws {
        let registry = DexterExecutionStateMachineRegistry()
        let machine = DexterExecutionStateMachine(actionIdentifier: UUID())
        registry.register(machine)
        try machine.transition(to: .understanding, progressSummary: "Understanding.")
        #expect(registry.latestSnapshot()?.currentPhase == .understanding)
    }

    @Test func everyAllowedTransitionSucceeds() throws {
        let allowedEdges: [(DexterExecutionPhase, DexterExecutionPhase)] = [
            (.received, .understanding),
            (.received, .failed),
            (.received, .cancelled),
            (.understanding, .planning),
            (.understanding, .failed),
            (.understanding, .cancelled),
            (.planning, .waitingPermission),
            (.planning, .executing),
            (.planning, .completed),
            (.planning, .failed),
            (.planning, .cancelled),
            (.waitingPermission, .executing),
            (.waitingPermission, .failed),
            (.waitingPermission, .cancelled),
            (.executing, .verifying),
            (.executing, .failed),
            (.executing, .cancelled),
            (.verifying, .completed),
            (.verifying, .failed),
            (.verifying, .cancelled),
        ]

        for (fromPhase, toPhase) in allowedEdges {
            let machine = machineAtPhase(fromPhase)
            if toPhase == .failed {
                try machine.fail(code: "test", message: "Forced failure.")
            } else if toPhase == .cancelled {
                try machine.cancel(message: "Forced cancellation.")
            } else {
                try machine.transition(to: toPhase, progressSummary: "Transition \(fromPhase.rawValue) → \(toPhase.rawValue).")
            }
            #expect(machine.snapshot.currentPhase == toPhase)
        }
    }

    @Test func disallowedTransitionsAreRejected() {
        for fromPhase in DexterExecutionPhase.allCases where !fromPhase.isTerminal {
            for toPhase in DexterExecutionPhase.allCases {
                guard !DexterExecutionStateMachineTransitionRules.canTransition(from: fromPhase, to: toPhase) else {
                    continue
                }
                let machine = machineAtPhase(fromPhase)
                #expect(
                    throws: DexterExecutionStateMachineError.invalidTransition(from: fromPhase, to: toPhase)
                ) {
                    try machine.transition(to: toPhase, progressSummary: "Should not succeed.")
                }
            }
        }
    }

    @Test func timeoutBlocksContinuation() throws {
        let pastReceivedAt = Date().addingTimeInterval(-300)
        let machine = DexterExecutionStateMachine(
            actionIdentifier: UUID(),
            timeoutSeconds: 60,
            receivedAt: pastReceivedAt
        )
        #expect(throws: DexterExecutionStateMachineError.timedOut) {
            try machine.checkContinuationAllowed()
        }
    }

    private func machineAtPhase(_ phase: DexterExecutionPhase) -> DexterExecutionStateMachine {
        makeMachine(at: phase)
    }

    private func makeMachine(at phase: DexterExecutionPhase) -> DexterExecutionStateMachine {
        let machine = DexterExecutionStateMachine(actionIdentifier: UUID())
        switch phase {
        case .received:
            return machine
        case .understanding:
            try? machine.transition(to: .understanding, progressSummary: "Understanding.")
            return machine
        case .planning:
            try? machine.transition(to: .understanding, progressSummary: "Understanding.")
            try? machine.transition(to: .planning, progressSummary: "Planning.")
            return machine
        case .waitingPermission:
            try? machine.transition(to: .understanding, progressSummary: "Understanding.")
            try? machine.transition(to: .planning, progressSummary: "Planning.")
            try? machine.transition(to: .waitingPermission, progressSummary: "Waiting.")
            return machine
        case .executing:
            try? machine.transition(to: .understanding, progressSummary: "Understanding.")
            try? machine.transition(to: .planning, progressSummary: "Planning.")
            try? machine.transition(to: .executing, progressSummary: "Executing.")
            return machine
        case .verifying:
            try? machine.transition(to: .understanding, progressSummary: "Understanding.")
            try? machine.transition(to: .planning, progressSummary: "Planning.")
            try? machine.transition(to: .executing, progressSummary: "Executing.")
            try? machine.transition(to: .verifying, progressSummary: "Verifying.")
            return machine
        case .completed, .failed, .cancelled:
            try? machine.transition(to: .understanding, progressSummary: "Understanding.")
            try? machine.transition(to: .planning, progressSummary: "Planning.")
            try? machine.transition(to: .completed, progressSummary: "Done.")
            return machine
        }
    }
}
