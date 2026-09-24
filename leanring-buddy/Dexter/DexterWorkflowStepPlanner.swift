//
//  DexterWorkflowStepPlanner.swift
//  leanring-buddy
//

import Foundation

enum DexterWorkflowStepPlanOutcome: Equatable {
    case planned(DexterAction)
    case waitForUser(String)
    case askUser(String)
    case failed(String)
}

/// Plans semantic actions from workflow steps using fresh context only (no replay of coordinates).
enum DexterWorkflowStepPlanner {
    static func plan(
        step: DexterWorkflowStepDefinition,
        workflow: DexterLearnedWorkflow,
        context: DexterContext
    ) -> DexterWorkflowStepPlanOutcome {
        if step.parameters["x"] != nil || step.parameters["y"] != nil {
            return .failed("Workflow steps cannot include screen coordinates.")
        }

        switch step.actionKind {
        case .openApplication:
            let applicationName = step.parameters["applicationName"] ?? ""
            guard !applicationName.isEmpty else {
                return .askUser("Which application should Dexter open for “\(step.title)”?")
            }
            return .planned(
                DexterActionFactory.openApplication(
                    named: applicationName,
                    contextSummary: "Workflow \(workflow.name): \(step.title)"
                )
            )

        case .openBrowser:
            return .planned(DexterActionFactory.browserOpen(url: "https://www.google.com", verificationHint: "google"))

        case .browserNavigate:
            let url = step.parameters["url"] ?? ""
            guard !url.isEmpty else {
                return .askUser("What URL should Dexter open for “\(step.title)”?")
            }
            var action = DexterActionFactory.browserNavigate(url: url)
            if let hint = step.parameters["verificationHint"] {
                action = DexterAction(
                    type: action.type,
                    parameters: action.parameters.merging(["verificationHint": hint]) { _, new in new },
                    riskLevel: action.riskLevel,
                    humanReadableDescription: action.humanReadableDescription,
                    state: action.state,
                    proposedAt: action.proposedAt,
                    updatedAt: action.updatedAt
                )
            }
            return .planned(action)

        case .runTerminalInspect:
            let commandTemplate = step.parameters["commandTemplate"] ?? ""
            guard !commandTemplate.isEmpty else {
                return .askUser("This workflow step needs an approved terminal command template id.")
            }
            return .planned(
                DexterActionFactory.terminalOperation(
                    terminalAction: "inspect",
                    commandTemplate: commandTemplate,
                    pathArgument: step.parameters["pathArgument"],
                    workingDirectory: step.parameters["workingDirectory"],
                    expectedOutputContains: nil,
                    riskLevel: .readOnly,
                    humanReadableDescription: "Workflow \(workflow.name): \(step.title)"
                )
            )

        case .waitForUserConfirmation:
            return .waitForUser(step.instruction)

        case .askUserWhenUncertain:
            let prompt = step.parameters["prompt"] ?? step.instruction
            return .askUser(prompt)
        }
    }

    static func contextMeetsRequirements(
        step: DexterWorkflowStepDefinition,
        context: DexterContext
    ) -> (isSatisfied: Bool, missingDescription: String?) {
        let requirements = step.contextRequirements

        if requirements.requiresAccessibilityPermission,
           context.activeApplication.availability == .available {
            // Environment probe may still be unavailable; only block when explicitly required and missing.
        }

        if requirements.requiresApplicationLifecycleProbe,
           context.activeApplication.availability != .available {
            return (false, "Dexter needs active application context before “\(step.title)”. Grant Accessibility and try again.")
        }

        if requirements.requiredContextSections.contains("activeWindow"),
           context.activeWindow.availability != .available {
            return (false, "Dexter needs the active window title to continue “\(step.title)” without guessing.")
        }

        if requirements.requiresBrowserState || requirements.requiredContextSections.contains("browser") {
            let browserFrontmost = DexterBrowserStateCollector.isBrowserApplicationName(
                context.activeApplication.localizedName
            )
            if !browserFrontmost && step.actionKind == .browserNavigate {
                return (false, nil)
            }
        }

        return (true, nil)
    }
}
