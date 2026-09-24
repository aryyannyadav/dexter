//
//  DexterIntentPlanner.swift
//  leanring-buddy
//

import Foundation

enum DexterIntentPlanner {
    static func plan(for intent: DexterStructuredIntent) -> DexterIntentPlan? {
        switch intent.kind {
        case .fix:
            return fixErrorPlan(for: intent)
        case .automate:
            return automatePlan(for: intent)
        case .plan:
            return genericWorkflowPlan(for: intent, goal: "Plan the requested workflow.")
        case .run:
            return runActionPlan(for: intent)
        case .edit, .create:
            return modifyContentPlan(for: intent)
        default:
            return nil
        }
    }

    private static func fixErrorPlan(for intent: DexterStructuredIntent) -> DexterIntentPlan {
        DexterIntentPlan(
            goal: "Fix the error in the current context safely.",
            steps: [
                DexterIntentPlanStep(order: 1, identifier: "inspect", title: "Inspect the current context and error surface."),
                DexterIntentPlanStep(order: 2, identifier: "identify_cause", title: "Identify the likely cause."),
                DexterIntentPlanStep(order: 3, identifier: "propose_modification", title: "Propose a minimal modification."),
                DexterIntentPlanStep(order: 4, identifier: "permission", title: "Request permission before any change."),
                DexterIntentPlanStep(order: 5, identifier: "edit", title: "Apply the approved edit."),
                DexterIntentPlanStep(order: 6, identifier: "test", title: "Re-run or observe the affected surface."),
                DexterIntentPlanStep(order: 7, identifier: "verify", title: "Verify the expected state."),
                DexterIntentPlanStep(order: 8, identifier: "report", title: "Report verification outcome to the user."),
            ],
            requiredTools: ["inspectScreen", "explainContent", "typeText", "computerAct"],
            requiredPermissions: ["accessibility", "screenRecording"],
            expectedStates: ["error_cleared_or_explained", "user_approved_change_applied"],
            stopConditions: ["verification_failed", "permission_denied", "budget_exceeded", "timeout"],
            actionBudget: 3,
            toolBudget: 5,
            timeoutSeconds: 120
        )
    }

    private static func automatePlan(for intent: DexterStructuredIntent) -> DexterIntentPlan {
        genericWorkflowPlan(for: intent, goal: "Automate the requested multi-step workflow.")
    }

    private static func runActionPlan(for intent: DexterStructuredIntent) -> DexterIntentPlan {
        DexterIntentPlan(
            goal: "Execute the requested action with verification.",
            steps: [
                DexterIntentPlanStep(order: 1, identifier: "plan", title: "Select the approved action."),
                DexterIntentPlanStep(order: 2, identifier: "permission", title: "Confirm permissions and user approval."),
                DexterIntentPlanStep(order: 3, identifier: "execute", title: "Execute through the tool gateway."),
                DexterIntentPlanStep(order: 4, identifier: "verify", title: "Verify the outcome."),
                DexterIntentPlanStep(order: 5, identifier: "report", title: "Report results."),
            ],
            requiredTools: ["computerAct"],
            requiredPermissions: ["accessibility"],
            expectedStates: ["action_verified"],
            stopConditions: ["verification_failed", "cancelled"],
            actionBudget: 2,
            toolBudget: 3,
            timeoutSeconds: 90
        )
    }

    private static func modifyContentPlan(for intent: DexterStructuredIntent) -> DexterIntentPlan {
        DexterIntentPlan(
            goal: intent.kind == .create ? "Create the requested content." : "Edit the requested content.",
            steps: [
                DexterIntentPlanStep(order: 1, identifier: "inspect", title: "Inspect current content context."),
                DexterIntentPlanStep(order: 2, identifier: "draft", title: "Draft the change."),
                DexterIntentPlanStep(order: 3, identifier: "permission", title: "Confirm before applying."),
                DexterIntentPlanStep(order: 4, identifier: "apply", title: "Apply the approved change."),
                DexterIntentPlanStep(order: 5, identifier: "verify", title: "Verify the result."),
                DexterIntentPlanStep(order: 6, identifier: "report", title: "Report outcome."),
            ],
            requiredTools: ["typeText", "inspectScreen"],
            requiredPermissions: ["accessibility"],
            expectedStates: ["content_updated"],
            stopConditions: ["permission_denied", "verification_failed"],
            actionBudget: 2,
            toolBudget: 4,
            timeoutSeconds: 90
        )
    }

    private static func genericWorkflowPlan(for intent: DexterStructuredIntent, goal: String) -> DexterIntentPlan {
        DexterIntentPlan(
            goal: goal,
            steps: [
                DexterIntentPlanStep(order: 1, identifier: "understand", title: "Understand the goal and constraints."),
                DexterIntentPlanStep(order: 2, identifier: "plan_steps", title: "Break the work into bounded steps."),
                DexterIntentPlanStep(order: 3, identifier: "permission", title: "Confirm risky steps with the user."),
                DexterIntentPlanStep(order: 4, identifier: "execute", title: "Execute one step at a time."),
                DexterIntentPlanStep(order: 5, identifier: "verify", title: "Verify each step."),
                DexterIntentPlanStep(order: 6, identifier: "report", title: "Report progress and completion."),
            ],
            requiredTools: ["computerAct", "inspectScreen"],
            requiredPermissions: ["accessibility", "screenRecording"],
            expectedStates: ["workflow_step_completed"],
            stopConditions: ["user_cancelled", "verification_failed", "timeout"],
            actionBudget: 3,
            toolBudget: 5,
            timeoutSeconds: 180
        )
    }
}
