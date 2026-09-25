//
//  DexterRuntimeUIState.swift
//  leanring-buddy
//
//  Menu bar / panel UI state driven by the execution state machine, voice lifecycle, and orchestrator hints.
//

import Combine
import Foundation

enum DexterRuntimeUIState: String, Equatable, CaseIterable {
    case idle = "IDLE"
    case listening = "LISTENING"
    case understanding = "UNDERSTANDING"
    case thinking = "THINKING"
    case planning = "PLANNING"
    case waitingPermission = "WAITING_PERMISSION"
    case acting = "ACTING"
    case verifying = "VERIFYING"
    case done = "DONE"
    case failed = "FAILED"
    case cancelled = "CANCELLED"

    var isTerminal: Bool {
        switch self {
        case .done, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}

struct DexterRuntimeUIFailurePresentation: Equatable {
    let whatFailed: String
    let why: String
    let whatYouCanDoNext: String
}

struct DexterRuntimeUIResolvedState: Equatable {
    let state: DexterRuntimeUIState
    let detail: String
    let failurePresentation: DexterRuntimeUIFailurePresentation?
}

enum DexterRuntimeUIFailureGuidance {
    static func nextSteps(forErrorCode errorCode: String) -> String {
        switch errorCode {
        case "permission_denied":
            return "Grant the required permission in System Settings, then ask Dexter to try again."
        case "verification_failed":
            return "Check that the target app or page changed as expected, then repeat the action or describe what you see."
        case "cancelled":
            return "You can start a new request when you're ready."
        case "timed_out":
            return "Try again with a simpler step, or confirm the app you need is open and responsive."
        case "action_budget_exceeded", "tool_budget_exceeded":
            return "Break the task into smaller steps and run them one at a time."
        default:
            return "Try again, or rephrase what you want Dexter to do."
        }
    }
}

enum DexterRuntimeUIStateResolver {
    static func resolve(
        executionSnapshot: DexterExecutionMachineSnapshot?,
        voiceInteractionState: DexterVoiceInteractionState,
        orchestratorPhaseOverride: DexterRuntimeUIState?,
        orchestratorDetailOverride: String
    ) -> DexterRuntimeUIResolvedState {
        if let executionSnapshot {
            return resolveFromExecutionSnapshot(executionSnapshot)
        }

        if voiceInteractionState == .listening {
            return DexterRuntimeUIResolvedState(
                state: .listening,
                detail: "Capture your request",
                failurePresentation: nil
            )
        }

        if voiceInteractionState == .transcribing {
            return DexterRuntimeUIResolvedState(
                state: .understanding,
                detail: "Transcribing your voice",
                failurePresentation: nil
            )
        }

        if let orchestratorPhaseOverride {
            let detail = orchestratorDetailOverride.isEmpty
                ? defaultDetail(for: orchestratorPhaseOverride)
                : orchestratorDetailOverride
            return DexterRuntimeUIResolvedState(
                state: orchestratorPhaseOverride,
                detail: detail,
                failurePresentation: nil
            )
        }

        if voiceInteractionState == .thinking {
            return DexterRuntimeUIResolvedState(
                state: .thinking,
                detail: "Working on your request",
                failurePresentation: nil
            )
        }

        if voiceInteractionState == .speaking {
            return DexterRuntimeUIResolvedState(
                state: .done,
                detail: "Speaking the response",
                failurePresentation: nil
            )
        }

        return DexterRuntimeUIResolvedState(state: .idle, detail: "", failurePresentation: nil)
    }

    private static func resolveFromExecutionSnapshot(
        _ executionSnapshot: DexterExecutionMachineSnapshot
    ) -> DexterRuntimeUIResolvedState {
        let progressSummary = executionSnapshot.progressSummary ?? ""

        switch executionSnapshot.currentPhase {
        case .received, .understanding:
            return DexterRuntimeUIResolvedState(
                state: .understanding,
                detail: progressSummary.isEmpty ? "Understanding the request" : progressSummary,
                failurePresentation: nil
            )
        case .planning:
            return DexterRuntimeUIResolvedState(
                state: .planning,
                detail: progressSummary.isEmpty ? "Planning next steps" : progressSummary,
                failurePresentation: nil
            )
        case .waitingPermission:
            return DexterRuntimeUIResolvedState(
                state: .waitingPermission,
                detail: progressSummary.isEmpty ? "Waiting for your approval" : progressSummary,
                failurePresentation: nil
            )
        case .executing:
            return DexterRuntimeUIResolvedState(
                state: .acting,
                detail: progressSummary.isEmpty ? "Running the approved action" : progressSummary,
                failurePresentation: nil
            )
        case .verifying:
            return DexterRuntimeUIResolvedState(
                state: .verifying,
                detail: "Checking…",
                failurePresentation: nil
            )
        case .completed:
            return DexterRuntimeUIResolvedState(
                state: .done,
                detail: progressSummary,
                failurePresentation: nil
            )
        case .failed:
            let errorInfo = executionSnapshot.errorInfo
            let errorCode = errorInfo?.code ?? "execution_failed"
            let whyMessage = errorInfo?.message ?? progressSummary
            return DexterRuntimeUIResolvedState(
                state: .failed,
                detail: whyMessage,
                failurePresentation: DexterRuntimeUIFailurePresentation(
                    whatFailed: "Dexter couldn't finish the action",
                    why: whyMessage,
                    whatYouCanDoNext: DexterRuntimeUIFailureGuidance.nextSteps(forErrorCode: errorCode)
                )
            )
        case .cancelled:
            let whyMessage = executionSnapshot.errorInfo?.message ?? progressSummary
            return DexterRuntimeUIResolvedState(
                state: .cancelled,
                detail: whyMessage,
                failurePresentation: DexterRuntimeUIFailurePresentation(
                    whatFailed: "The action was cancelled",
                    why: whyMessage.isEmpty ? "You or Dexter stopped before completion." : whyMessage,
                    whatYouCanDoNext: DexterRuntimeUIFailureGuidance.nextSteps(forErrorCode: "cancelled")
                )
            )
        }
    }

    private static func defaultDetail(for state: DexterRuntimeUIState) -> String {
        switch state {
        case .idle:
            return ""
        case .listening:
            return "Capture your request"
        case .understanding:
            return "Gathering context"
        case .thinking:
            return "Working on your request"
        case .planning:
            return "Planning next steps"
        case .waitingPermission:
            return "Waiting for your approval"
        case .acting:
            return "Running the approved action"
        case .verifying:
            return "Checking…"
        case .done:
            return "Ready"
        case .failed, .cancelled:
            return ""
        }
    }
}

@MainActor
final class DexterRuntimeUIStateStore: ObservableObject {
    @Published private(set) var currentState: DexterRuntimeUIState = .idle
    @Published private(set) var statusDetail: String = ""
    @Published private(set) var failurePresentation: DexterRuntimeUIFailurePresentation?

    private(set) var activeExecutionSnapshot: DexterExecutionMachineSnapshot?
    private var executionSnapshot: DexterExecutionMachineSnapshot? {
        get { activeExecutionSnapshot }
        set { activeExecutionSnapshot = newValue }
    }
    private var voiceInteractionState: DexterVoiceInteractionState = .idle
    private var orchestratorPhaseOverride: DexterRuntimeUIState?
    private var orchestratorDetailOverride: String = ""

    func applyExecutionSnapshot(_ snapshot: DexterExecutionMachineSnapshot) {
        executionSnapshot = snapshot
        if !snapshot.currentPhase.isTerminal {
            orchestratorPhaseOverride = nil
            orchestratorDetailOverride = ""
        }
        publishResolvedState()
    }

    func setVoiceInteractionState(_ interactionState: DexterVoiceInteractionState) {
        voiceInteractionState = interactionState
        publishResolvedState()
    }

    /// Lifecycle hints from orchestrator when no execution snapshot is active yet.
    func transition(to state: DexterRuntimeUIState, detail: String = "") {
        if let executionSnapshot, !executionSnapshot.currentPhase.isTerminal {
            return
        }
        orchestratorPhaseOverride = state == .idle ? nil : state
        orchestratorDetailOverride = detail
        publishResolvedState()
    }

    func reset() {
        executionSnapshot = nil
        orchestratorPhaseOverride = nil
        orchestratorDetailOverride = ""
        failurePresentation = nil
        currentState = .idle
        statusDetail = ""
    }

    private func publishResolvedState() {
        let resolved = DexterRuntimeUIStateResolver.resolve(
            executionSnapshot: executionSnapshot,
            voiceInteractionState: voiceInteractionState,
            orchestratorPhaseOverride: orchestratorPhaseOverride,
            orchestratorDetailOverride: orchestratorDetailOverride
        )
        currentState = resolved.state
        statusDetail = resolved.detail
        failurePresentation = resolved.failurePresentation
    }
}

// Legacy name used across orchestrator and panel wiring.
typealias DexterDemonstrationPhaseStore = DexterRuntimeUIStateStore
