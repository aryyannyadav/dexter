//
//  DexterAccountabilityQueryEngine.swift
//  leanring-buddy
//

import Foundation

/// Answers accountability questions from persisted tasks/memory only.
enum DexterAccountabilityQueryEngine {
    static func respond(
        queryKind: DexterAccountabilityQueryKind,
        snapshot: DexterAccountabilityTaskSnapshot,
        legacyTaskDescription: String?,
        workflowSummary: String?
    ) -> String {
        switch queryKind {
        case .whatAmIWorkingOn:
            return whatAmIWorkingOn(
                snapshot: snapshot,
                legacyTaskDescription: legacyTaskDescription,
                workflowSummary: workflowSummary
            )
        case .whatsNext:
            return whatsNext(snapshot: snapshot, legacyTaskDescription: legacyTaskDescription)
        case .whatDidILeaveUnfinished:
            return whatDidILeaveUnfinished(snapshot: snapshot)
        case .continueMyWork:
            return continueMyWork(
                snapshot: snapshot,
                legacyTaskDescription: legacyTaskDescription,
                workflowSummary: workflowSummary
            )
        }
    }

    private static func whatAmIWorkingOn(
        snapshot: DexterAccountabilityTaskSnapshot,
        legacyTaskDescription: String?,
        workflowSummary: String?
    ) -> String {
        if let activeTask = snapshot.activeTask {
            return groundedActiveTaskLine(activeTask)
        }

        if let inProgress = snapshot.openTasks.first(where: { $0.status == .inProgress }) {
            return groundedActiveTaskLine(inProgress)
        }

        if let legacyTaskDescription = legacyTaskDescription?.nonEmptyTrimmedValue {
            return "Your saved task description is: \(legacyTaskDescription)."
        }

        if let workflowSummary = workflowSummary?.nonEmptyTrimmedValue {
            return "You have an active workflow: \(workflowSummary). I don't have a separate structured task record."
        }

        return "I don't have a stored task or workflow. Say “my task is …” or “remind me to …” to create one."
    }

    private static func whatsNext(
        snapshot: DexterAccountabilityTaskSnapshot,
        legacyTaskDescription: String?
    ) -> String {
        if let activeTask = snapshot.activeTask ?? snapshot.openTasks.first,
           let nextStep = activeTask.nextIncompleteStep {
            return "Next for “\(activeTask.title)”: \(nextStep.title)."
        }

        if let activeTask = snapshot.activeTask ?? snapshot.openTasks.first {
            if let goal = activeTask.goal?.nonEmptyTrimmedValue {
                return "No open steps on “\(activeTask.title)”. Goal on file: \(goal)."
            }
            return "“\(activeTask.title)” has no incomplete steps recorded. Add steps or tell me what to do next."
        }

        if let legacyTaskDescription = legacyTaskDescription?.nonEmptyTrimmedValue {
            return "Only a legacy task description is stored: \(legacyTaskDescription). I can't infer next steps without you defining them."
        }

        return "I don't have stored tasks with next steps. Tell me your task and steps, or say “my task is …”."
    }

    private static func whatDidILeaveUnfinished(
        snapshot: DexterAccountabilityTaskSnapshot
    ) -> String {
        let unfinished = snapshot.unfinishedTasks
        guard !unfinished.isEmpty else {
            return "I don't have any unfinished structured tasks saved."
        }

        let lines = unfinished.prefix(5).map { task in
            let stepHint = task.nextIncompleteStep.map { " — next: \($0.title)" } ?? ""
            return "• \(task.title) (\(task.status.rawValue))\(stepHint)"
        }
        return "Unfinished tasks on file:\n" + lines.joined(separator: "\n")
    }

    private static func continueMyWork(
        snapshot: DexterAccountabilityTaskSnapshot,
        legacyTaskDescription: String?,
        workflowSummary: String?
    ) -> String {
        var parts: [String] = []

        if let activeTask = snapshot.activeTask ?? snapshot.openTasks.first {
            parts.append(groundedActiveTaskLine(activeTask))
            if let nextStep = activeTask.nextIncompleteStep {
                parts.append("Continue with step: \(nextStep.title).")
            }
        } else if let legacyTaskDescription = legacyTaskDescription?.nonEmptyTrimmedValue {
            parts.append("Continue: \(legacyTaskDescription).")
        }

        if let workflowSummary = workflowSummary?.nonEmptyTrimmedValue {
            parts.append("Workflow in progress: \(workflowSummary).")
        }

        if parts.isEmpty {
            return "I don't have saved work to continue. Describe the task or say “my task is …”."
        }

        return parts.joined(separator: " ")
    }

    private static func groundedActiveTaskLine(_ task: DexterAccountabilityTask) -> String {
        var line = "You're working on “\(task.title)” (\(task.status.rawValue))."
        if let project = task.project?.nonEmptyTrimmedValue {
            line += " Project: \(project)."
        }
        if let deadline = task.deadline {
            line += " Deadline: \(ISO8601DateFormatter().string(from: deadline))."
        }
        return line
    }
}
