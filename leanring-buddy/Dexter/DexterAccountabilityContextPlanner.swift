//
//  DexterAccountabilityContextPlanner.swift
//  leanring-buddy
//

import Foundation

/// Planner hints derived from stored accountability tasks (no fabricated commitments).
enum DexterAccountabilityContextPlanner {
    static func intentPlanSupplement(for snapshot: DexterAccountabilityTaskSnapshot) -> DexterIntentPlan? {
        guard let activeTask = snapshot.activeTask ?? snapshot.openTasks.first else {
            return nil
        }

        let stepTitles = activeTask.steps.filter { !$0.isCompleted }.map(\.title)
        let goalLine = activeTask.goal ?? activeTask.title

        return DexterIntentPlan(
            goal: goalLine,
            steps: stepTitles.enumerated().map { index, title in
                DexterIntentPlanStep(order: index + 1, identifier: "accountability_step_\(index + 1)", title: title)
            },
            requiredTools: [],
            requiredPermissions: [],
            expectedStates: ["task_progress_verified"],
            stopConditions: ["user_cancelled", "verification_failed"],
            actionBudget: 2,
            toolBudget: 2,
            timeoutSeconds: 120
        )
    }

    static func promptSummary(for snapshot: DexterAccountabilityTaskSnapshot) -> String? {
        guard snapshot.activeTask != nil || !snapshot.openTasks.isEmpty else {
            return nil
        }

        var lines: [String] = []
        if let activeTask = snapshot.activeTask {
            lines.append("active_task: \(activeTask.title) [\(activeTask.status.rawValue)]")
            if let nextStep = activeTask.nextIncompleteStep {
                lines.append("next_step: \(nextStep.title)")
            }
        }

        let openTitles = snapshot.openTasks.prefix(4).map(\.title)
        if !openTitles.isEmpty {
            lines.append("open_tasks: \(openTitles.joined(separator: "; "))")
        }

        return lines.joined(separator: "\n")
    }
}
