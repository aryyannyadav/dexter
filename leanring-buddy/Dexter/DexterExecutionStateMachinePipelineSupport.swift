//
//  DexterExecutionStateMachinePipelineSupport.swift
//  leanring-buddy
//

import Foundation

enum DexterExecutionStateMachinePipelineSupport {
    static func ensurePlanningPhase(_ stateMachine: DexterExecutionStateMachine) throws {
        switch stateMachine.snapshot.currentPhase {
        case .received:
            try stateMachine.transition(to: .understanding, progressSummary: "Understanding the computer action request.")
            try stateMachine.transition(to: .planning, progressSummary: "Planning the approved action.")
        case .understanding:
            try stateMachine.transition(to: .planning, progressSummary: "Planning the approved action.")
        case .planning, .waitingPermission, .executing, .verifying, .completed, .failed, .cancelled:
            break
        }
    }

    static func userFacingMessage(for error: DexterExecutionStateMachineError) -> String {
        switch error {
        case .invalidTransition:
            return "Dexter could not advance the action because its execution state was inconsistent."
        case .cancellationRequested:
            return "The action was cancelled."
        case .actionBudgetExceeded:
            return "Dexter stopped because this turn exceeded its action budget."
        case .toolBudgetExceeded:
            return "Dexter stopped because this turn exceeded its tool budget."
        case .timedOut:
            return "The action timed out before it could finish."
        }
    }

    static func failCode(for error: DexterExecutionStateMachineError) -> String {
        switch error {
        case .invalidTransition:
            return "invalid_transition"
        case .cancellationRequested:
            return "cancelled"
        case .actionBudgetExceeded:
            return "action_budget_exceeded"
        case .toolBudgetExceeded:
            return "tool_budget_exceeded"
        case .timedOut:
            return "timed_out"
        }
    }
}
