//
//  DexterSkillPromptBuilder.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillPromptBuilder {
    static func promptSection(for skill: DexterSkill, mergedPlan: DexterIntentPlan?) -> String {
        var lines: [String] = []
        lines.append("skill_id: \(skill.id.rawValue)")
        lines.append("skill_name: \(skill.name)")
        lines.append("skill_version: \(skill.version)")
        lines.append("description: \(skill.description)")

        if !skill.requiredCapabilities.isEmpty {
            lines.append("required_capabilities: \(skill.requiredCapabilities.joined(separator: ", "))")
        }

        if !skill.permissions.isEmpty {
            lines.append("permissions: \(skill.permissions.joined(separator: ", "))")
        }

        if let workflowIdentifier = skill.workflow.workflowIdentifier {
            lines.append("workflow_identifier: \(workflowIdentifier)")
        }

        lines.append("verification_policy: \(skill.verification.policy)")
        if skill.verification.stopOnUncertainty {
            lines.append("on_uncertainty: stop_and_ask_user")
        }

        if !skill.inputs.isEmpty {
            let inputSummary = skill.inputs.map { input in
                let requiredLabel = input.isRequired ? "required" : "optional"
                return "\(input.id) (\(requiredLabel)): \(input.description)"
            }
            lines.append("inputs: \(inputSummary.joined(separator: "; "))")
        }

        if let mergedPlan {
            lines.append("plan_goal: \(mergedPlan.goal)")
            lines.append("plan_action_budget: \(mergedPlan.actionBudget)")
        }

        if !skill.composableWithSkillIds.isEmpty {
            let composableIds = skill.composableWithSkillIds.map(\.rawValue).joined(separator: ", ")
            lines.append("composable_with: \(composableIds)")
        }

        return lines.joined(separator: "\n")
    }
}
