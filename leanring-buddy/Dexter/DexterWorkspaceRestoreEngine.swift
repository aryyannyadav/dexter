//
//  DexterWorkspaceRestoreEngine.swift
//  leanring-buddy
//

import Foundation

struct DexterWorkspaceRestoreRunResult: Equatable {
    let userMessage: String
    let comparison: DexterWorkspaceRestoreComparison
    let executedStepSummaries: [String]
    let stoppedAwaitingPermission: Bool
}

enum DexterWorkspaceRestoreEngine {
    @MainActor
    static func runRestore(
        desiredSnapshot: DexterWorkspaceSnapshot,
        currentState: DexterWorkspaceCurrentState,
        memoryStore: MemoryStore,
        executeVerifiedAction: (DexterAction) async -> DexterActionExecutionOutcome
    ) async -> DexterWorkspaceRestoreRunResult {
        DexterObservabilityLog.plan("workspace restore inspect started snapshot_id=\(desiredSnapshot.id.uuidString.prefix(8))")

        let comparison = DexterWorkspaceRestorePlanner.compare(
            desiredSnapshot: desiredSnapshot,
            currentState: currentState
        )
        let steps = DexterWorkspaceRestorePlanner.planSteps(
            desiredSnapshot: desiredSnapshot,
            comparison: comparison
        )

        var planMessage = DexterWorkspaceRestorePlanner.planSummaryText(
            desiredSnapshot: desiredSnapshot,
            comparison: comparison,
            steps: steps
        )

        if steps.isEmpty {
            DexterObservabilityLog.plan("workspace restore complete aligned=true")
            return DexterWorkspaceRestoreRunResult(
                userMessage: planMessage,
                comparison: comparison,
                executedStepSummaries: [],
                stoppedAwaitingPermission: false
            )
        }

        var executedSummaries: [String] = []
        var stoppedAwaitingPermission = false

        for step in steps {
            switch step.kind {
            case .restoreTaskMemory:
                if let taskDescription = step.taskDescriptionToRestore {
                    memoryStore.setActiveTask(
                        description: taskDescription,
                        provenance: .explicitUserRequest
                    )
                    executedSummaries.append("Restored active task memory.")
                    DexterObservabilityLog.memory("workspace restore task_memory updated")
                }

            case .restoreAccountabilityTaskFocus:
                if let identifier = step.accountabilityTaskIdentifier {
                    memoryStore.setActiveAccountabilityTaskIdentifier(identifier)
                    executedSummaries.append(step.humanReadableDescription)
                    DexterObservabilityLog.memory("workspace restore accountability focus updated")
                }

            case .openApplication, .focusApplication, .openBrowserURL:
                guard let proposedAction = step.proposedAction else { continue }
                DexterObservabilityLog.plan("workspace restore execute action=\(proposedAction.type.rawValue)")
                let outcome = await executeVerifiedAction(proposedAction)
                executedSummaries.append(outcome.spokenSummary)

                if outcome.pendingConfirmation != nil {
                    stoppedAwaitingPermission = true
                    planMessage += " I need your approval in the Dexter panel before continuing the workspace restore."
                    break
                }

                if outcome.action.state == .failed || outcome.action.state == .verificationFailed {
                    planMessage += " Workspace restore stopped because an action did not verify."
                    break
                }

            case .informUser:
                executedSummaries.append(step.humanReadableDescription)
            }
        }

        if !executedSummaries.isEmpty {
            planMessage += " Results: \(executedSummaries.joined(separator: " "))"
        }

        DexterObservabilityLog.plan(
            "workspace restore finished steps=\(executedSummaries.count) awaiting_permission=\(stoppedAwaitingPermission)"
        )

        return DexterWorkspaceRestoreRunResult(
            userMessage: planMessage,
            comparison: comparison,
            executedStepSummaries: executedSummaries,
            stoppedAwaitingPermission: stoppedAwaitingPermission
        )
    }
}
