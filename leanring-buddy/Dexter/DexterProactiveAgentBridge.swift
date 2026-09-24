//
//  DexterProactiveAgentBridge.swift
//  leanring-buddy
//

import Foundation

enum DexterProactiveAgentBridge {
    static func proposeAction(
        for event: DexterProactiveEvent,
        context: DexterContext,
        automationRegistration: DexterProactiveAutomationRegistration?
    ) -> DexterAction? {
        guard let workflowIdentifier = automationRegistration?.linkedWorkflowIdentifier,
              event.kind == .workflowRepetition,
              DexterWorkflowCatalog.workflow(forIdentifier: workflowIdentifier) != nil else {
            return lowRiskSuggestionAction(for: event, context: context)
        }

        return nil
    }

    private static func lowRiskSuggestionAction(for event: DexterProactiveEvent, context: DexterContext) -> DexterAction? {
        switch event.kind {
        case .applicationState:
            let applicationName = event.metadata["bundle_identifier"] ?? event.title
            if DexterBrowserStateCollector.isBrowserApplicationName(context.activeApplication.localizedName) {
                return nil
            }
            return DexterActionFactory.openApplication(
                named: context.activeApplication.localizedName ?? applicationName,
                contextSummary: "Proactive application-state follow-up for \(event.title)"
            )
        case .newFile:
            guard let path = event.metadata["path"] else { return nil }
            return DexterActionFactory.terminalOperation(
                terminalAction: "inspect",
                commandTemplate: "inspect_pwd",
                pathArgument: path,
                workingDirectory: nil,
                expectedOutputContains: nil,
                riskLevel: .readOnly,
                humanReadableDescription: "Proactive inspect for new file context"
            )
        case .taskDeadlineApproaching, .workflowRepetition, .calendarEvent:
            return nil
        }
    }
}
