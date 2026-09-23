//
//  DexterTaskWorkflowRunner.swift
//  leanring-buddy
//

import Foundation

struct DexterTaskWorkflowTurnOutcome: Equatable {
    let task: DexterTask
    let spokenSummary: String
    let didHandleTurn: Bool
    let requiresScreenContext: Bool
}

enum DexterTaskWorkflowRunner {
    static func shouldCancelWorkflow(forUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased()
        return normalized.contains("cancel workflow")
            || normalized.contains("cancel task")
            || normalized.contains("stop this workflow")
    }

    static func userApprovedSubmission(forUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased()
        let approvalPhrases = [
            "yes submit",
            "go ahead and submit",
            "approve submission",
            "i approve submitting",
            "you can submit",
            "allow submission"
        ]
        return approvalPhrases.contains { normalized.contains($0) }
    }

    static func userContinuesWorkflow(forUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let continuePhrases = ["continue", "next", "ready", "done", "ok", "okay", "proceed"]
        return continuePhrases.contains { normalized == $0 || normalized.hasPrefix("\($0) ") }
    }

    /// Advances a bounded workflow one turn. Uses AgentRuntime only on the allowlisted Safari step.
    static func processTurn(
        userMessage: String,
        task: DexterTask,
        context: DexterContext,
        executeVerifiedAction: (DexterAction) async -> DexterActionExecutionOutcome
    ) async -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task

        if shouldCancelWorkflow(forUserMessage: userMessage) {
            updatedTask.state = .cancelled
            updatedTask.updatedAt = Date()
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Cancelled the assignment workflow. Say “help me submit this assignment” to start again.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        if updatedTask.isTerminal {
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "This workflow is already finished.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        guard let currentStep = updatedTask.currentStep else {
            updatedTask.state = .failed
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "The workflow has no remaining steps.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        switch currentStep.kind {
        case .inspectAssignmentOnScreen:
            return await handleInspectAssignmentStep(userMessage: userMessage, task: updatedTask, context: context)

        case .openBrowserForSubmission:
            return await handleOpenBrowserStep(
                userMessage: userMessage,
                task: updatedTask,
                context: context,
                executeVerifiedAction: executeVerifiedAction
            )

        case .inspectRequiredFields:
            return handleInspectRequiredFieldsStep(userMessage: userMessage, task: updatedTask, context: context)

        case .prepareUploadGuidance:
            return handlePrepareUploadStep(userMessage: userMessage, task: updatedTask)

        case .requestSubmissionPermission:
            return handlePermissionStep(userMessage: userMessage, task: updatedTask)

        case .guideFinalSubmission:
            return handleGuideFinalSubmissionStep(userMessage: userMessage, task: updatedTask, context: context)

        case .verifySubmission:
            return handleVerifySubmissionStep(userMessage: userMessage, task: updatedTask, context: context)

        case .reportCompletion:
            return handleReportStep(task: updatedTask)
        }
    }

    private static func handleInspectAssignmentStep(
        userMessage: String,
        task: DexterTask,
        context: DexterContext
    ) async -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task

        if !userContinuesWorkflow(forUserMessage: userMessage) {
            let screenHint = screenAvailabilityHint(from: context)
            updatedTask.state = .waitingForUser
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 1 — Inspect assignment. \(screenHint) I'll look at what's on screen with your next message. Say “continue” when you're on the assignment instructions.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        let assignmentHint = context.activeWindow.title ?? context.activeApplication.localizedName ?? "the current window"
        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .waitingForUser
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 1 complete. I inspected \(assignmentHint) for assignment instructions. Step 2 — \(nextStep.title): say “continue” when you want me to open Safari for the submission page.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Step 1 complete.",
            didHandleTurn: true,
            requiresScreenContext: true
        )
    }

    private static func handleOpenBrowserStep(
        userMessage: String,
        task: DexterTask,
        context: DexterContext,
        executeVerifiedAction: (DexterAction) async -> DexterActionExecutionOutcome
    ) async -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task
        if !userContinuesWorkflow(forUserMessage: userMessage) {
            updatedTask.state = .waitingForUser
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 2 — Locate submission page. Say “continue” and I'll run the allowlisted action to open Safari. You'll navigate to the LMS yourself.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        updatedTask.state = .executing
        updatedTask = markCurrentStep(updatedTask, stepState: .executing)

        let openSafariAction = DexterActionFactory.openApplication(
            named: "Safari",
            contextSummary: "Assignment submission workflow step: open browser for LMS."
        )
        let actionOutcome = await executeVerifiedAction(openSafariAction)

        updatedTask.state = .verifying
        updatedTask = markCurrentStep(updatedTask, stepState: .verifying)

        guard actionOutcome.action.state == .completed else {
            updatedTask.state = .failed
            updatedTask = markCurrentStep(updatedTask, stepState: .failed)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 2 failed: \(actionOutcome.spokenSummary)",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .waitingForUser
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Step 2 complete. \(actionOutcome.spokenSummary) Navigate to your submission page, then say “continue” for step 3 — \(updatedTask.currentStep?.title ?? "inspect fields").",
            didHandleTurn: true,
            requiresScreenContext: false
        )
    }

    private static func handleInspectRequiredFieldsStep(
        userMessage: String,
        task: DexterTask,
        context: DexterContext
    ) -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task
        if !userContinuesWorkflow(forUserMessage: userMessage) {
            updatedTask.state = .waitingForUser
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 3 — Inspect required fields. Open the submission form, then say “continue” so I can review required uploads and fields on screen.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        let windowTitle = context.activeWindow.title ?? "the submission form"
        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .waitingForUser
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 3 complete. I checked \(windowTitle) for required fields. Step 4 — \(nextStep.title): attach your file, then say “continue”.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Step 3 complete.",
            didHandleTurn: true,
            requiresScreenContext: true
        )
    }

    private static func handlePrepareUploadStep(userMessage: String, task: DexterTask) -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task
        if !userContinuesWorkflow(forUserMessage: userMessage) {
            updatedTask.state = .waitingForUser
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 4 — Prepare upload. Attach the assignment file and double-check the filename. Say “continue” when the upload is ready.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .waitingForPermission
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForPermission)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 4 complete. Step 5 — Permission: I will not submit automatically. Say “I approve submitting” when you want to proceed to the final submit step.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Step 4 complete.",
            didHandleTurn: true,
            requiresScreenContext: false
        )
    }

    private static func handlePermissionStep(userMessage: String, task: DexterTask) -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task
        updatedTask.state = .waitingForPermission
        updatedTask = markCurrentStep(updatedTask, stepState: .waitingForPermission)

        if !userApprovedSubmission(forUserMessage: userMessage) {
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 5 — Waiting for permission. Dexter will not submit without explicit approval. Say “I approve submitting” to continue.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .waitingForUser
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Permission granted. Step 6 — Submit: click Submit yourself in the LMS. I won't auto-click. Say “continue” after you've submitted.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Permission recorded.",
            didHandleTurn: true,
            requiresScreenContext: false
        )
    }

    private static func handleGuideFinalSubmissionStep(
        userMessage: String,
        task: DexterTask,
        context: DexterContext
    ) -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task
        if !userContinuesWorkflow(forUserMessage: userMessage) {
            updatedTask.state = .waitingForUser
            updatedTask = markCurrentStep(updatedTask, stepState: .waitingForUser)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 6 — Submit manually in \(context.activeApplication.localizedName ?? "the browser"). Say “continue” once you've clicked Submit.",
                didHandleTurn: true,
                requiresScreenContext: false
            )
        }

        updatedTask.state = .executing
        updatedTask = markCurrentStep(updatedTask, stepState: .executing)
        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .verifying
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .verifying)
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 6 complete. Step 7 — Verify: say “continue” and I'll help confirm the confirmation screen or submitted status.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Step 6 complete.",
            didHandleTurn: true,
            requiresScreenContext: false
        )
    }

    private static func handleVerifySubmissionStep(
        userMessage: String,
        task: DexterTask,
        context: DexterContext
    ) -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = task
        updatedTask.state = .verifying
        updatedTask = markCurrentStep(updatedTask, stepState: .verifying)

        if !userContinuesWorkflow(forUserMessage: userMessage) {
            updatedTask.state = .waitingForUser
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 7 — Verify submission. Show the LMS confirmation or submitted status, then say “continue”.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        let windowTitle = context.activeWindow.title ?? "the current page"
        let looksSubmitted = windowTitle.lowercased().contains("submit")
            || windowTitle.lowercased().contains("confirm")
            || windowTitle.lowercased().contains("success")

        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .executing
        if let nextStep = updatedTask.currentStep {
            updatedTask = markCurrentStep(updatedTask, stepState: .executing)
            let verificationMessage = looksSubmitted
                ? "I see a likely confirmation in \(windowTitle)."
                : "I couldn't confirm submission automatically from \(windowTitle). Please verify the LMS shows submitted."
            return DexterTaskWorkflowTurnOutcome(
                task: updatedTask,
                spokenSummary: "Step 7 complete. \(verificationMessage) Step 8 — Final report: say “continue”.",
                didHandleTurn: true,
                requiresScreenContext: true
            )
        }

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Step 7 complete.",
            didHandleTurn: true,
            requiresScreenContext: true
        )
    }

    private static func handleReportStep(task: DexterTask) -> DexterTaskWorkflowTurnOutcome {
        var updatedTask = markCurrentStep(task, stepState: .executing)
        updatedTask = completeCurrentStepAndAdvance(updatedTask)
        updatedTask.state = .completed
        updatedTask = markCurrentStep(updatedTask, stepState: .completed)

        return DexterTaskWorkflowTurnOutcome(
            task: updatedTask,
            spokenSummary: "Workflow complete. I guided you through inspect, Safari, field check, upload prep, permission, manual submit, and verification. Double-check the LMS submission receipt and deadline.",
            didHandleTurn: true,
            requiresScreenContext: false
        )
    }

    private static func screenAvailabilityHint(from context: DexterContext) -> String {
        switch context.screen.captureAvailability {
        case .available:
            return "Screen capture is available."
        case .permissionMissing:
            return "Grant screen recording so I can read the assignment on screen."
        case .notApplicable:
            return "I'll use screen context on your next turn."
        case .unavailable(let errorDescription):
            return "Screen capture is unavailable (\(errorDescription))."
        }
    }

    private static func markCurrentStep(_ task: DexterTask, stepState: TaskState) -> DexterTask {
        var updatedTask = task
        guard updatedTask.steps.indices.contains(updatedTask.currentStepIndex) else { return updatedTask }
        updatedTask.steps[updatedTask.currentStepIndex].state = stepState
        updatedTask.updatedAt = Date()
        return updatedTask
    }

    private static func completeCurrentStepAndAdvance(_ task: DexterTask) -> DexterTask {
        var updatedTask = task
        guard updatedTask.steps.indices.contains(updatedTask.currentStepIndex) else { return updatedTask }
        updatedTask.steps[updatedTask.currentStepIndex].state = .completed
        updatedTask.currentStepIndex += 1
        updatedTask.updatedAt = Date()
        return updatedTask
    }
}
