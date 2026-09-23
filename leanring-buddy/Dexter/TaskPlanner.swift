//
//  TaskPlanner.swift
//  leanring-buddy
//

import Foundation

enum TaskPlanner {
    /// Returns a workflow only for explicit, allowlisted user goals. Never plans open-ended autonomy.
    static func planTaskIfRequested(forUserMessage userMessage: String) -> DexterTask? {
        let normalizedMessage = normalize(userMessage)

        if matchesAssignmentSubmissionGoal(normalizedMessage) {
            return assignmentSubmissionWorkflow(userGoalDescription: userMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }

    static func assignmentSubmissionWorkflow(userGoalDescription: String) -> DexterTask {
        let steps: [TaskStep] = [
            TaskStep(
                kind: .inspectAssignmentOnScreen,
                title: "Inspect assignment",
                instruction: "Review the assignment instructions visible on screen and summarize what must be submitted."
            ),
            TaskStep(
                kind: .openBrowserForSubmission,
                title: "Locate submission page",
                instruction: "Open Safari so you can navigate to the course submission page. Dexter will not browse autonomously."
            ),
            TaskStep(
                kind: .inspectRequiredFields,
                title: "Inspect required fields",
                instruction: "Check the submission form for required uploads, text fields, and deadlines."
            ),
            TaskStep(
                kind: .prepareUploadGuidance,
                title: "Prepare upload",
                instruction: "Confirm the file is ready and attached before any submit action."
            ),
            TaskStep(
                kind: .requestSubmissionPermission,
                title: "Ask permission before submit",
                instruction: "Dexter must get explicit approval before the final submission step."
            ),
            TaskStep(
                kind: .guideFinalSubmission,
                title: "Submit",
                instruction: "After approval, guide the final submit action without unrestricted automation."
            ),
            TaskStep(
                kind: .verifySubmission,
                title: "Verify submission",
                instruction: "Confirm the LMS shows a submitted or confirmation state."
            ),
            TaskStep(
                kind: .reportCompletion,
                title: "Report",
                instruction: "Summarize what was checked and what the user should verify."
            )
        ]

        return DexterTask(
            workflowIdentifier: "assignment_submission_v1",
            title: "Submit assignment",
            userGoalDescription: userGoalDescription,
            steps: steps,
            currentStepIndex: 0,
            state: .planning
        )
    }

    private static func matchesAssignmentSubmissionGoal(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "help me submit this assignment",
            "help me submit my assignment",
            "help me submit the assignment",
            "help me turn in this assignment",
            "help me turn in my assignment"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func normalize(_ userMessage: String) -> String {
        userMessage
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
