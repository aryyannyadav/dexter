//
//  DexterActionPlanner.swift
//  leanring-buddy
//

import Foundation

enum DexterActionPlanningOutcome: Equatable {
    case action(DexterAction)
    case unsupported(message: String)
    case notAnAction
}

enum DexterActionPlanner {
    static func planAction(
        forUserMessage userMessage: String,
        responseMode: DexterResponseMode,
        context: DexterContext,
        demonstrationSessionStore: DexterDemonstrationSessionStore
    ) -> DexterActionPlanningOutcome {
        guard responseMode == .act else {
            return .notAnAction
        }

        let normalizedMessage = normalize(userMessage)

        if let lifecycleIntent = DexterApplicationLifecycleIntentParser.parse(from: normalizedMessage) {
            let plannedAction = action(for: lifecycleIntent, context: context)
            return .action(plannedAction)
        }

        if matchesFixItIntent(normalizedMessage) {
            guard let fixText = demonstrationSessionStore.pendingCodeFixText else {
                return .unsupported(
                    message: "Ask Dexter to teach you why the error happens first so it can propose a [DEXTER_FIX:…] line, then say fix it."
                )
            }
            return .action(DexterActionFactory.typeText(fixText))
        }

        if DexterPointerControlWorkflow.matchesPointerActIntent(normalizedUserMessage: normalizedMessage) {
            guard let pointerLocation = DexterPointerControlWorkflow.validatedPointerLocationInScreenSpace(for: context) else {
                return .unsupported(message: DexterPointerControlWorkflow.pointFirstMessage)
            }
            let controlLabel = DexterPointerControlWorkflow.controlLabelForConfirmation(from: context)
            return .action(DexterActionFactory.clickAtScreenLocation(pointerLocation, label: controlLabel))
        }

        return .unsupported(
            message: "Dexter can open, focus, or quit applications through OpenClaw, explain what you're pointing at, apply a taught code fix, or click the control under your pointer."
        )
    }

    private static func action(for lifecycleIntent: DexterApplicationLifecycleIntent, context: DexterContext) -> DexterAction {
        let summary = contextSummary(from: context)
        switch lifecycleIntent.operation {
        case .launch:
            return DexterActionFactory.openApplication(named: lifecycleIntent.applicationName, contextSummary: summary)
        case .focus:
            return DexterActionFactory.focusApplication(named: lifecycleIntent.applicationName, contextSummary: summary)
        case .quit:
            return DexterActionFactory.quitApplication(named: lifecycleIntent.applicationName, contextSummary: summary)
        }
    }

    private static func matchesFixItIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage == "fix it"
            || normalizedMessage == "fix it for me"
            || normalizedMessage == "apply the fix"
            || normalizedMessage == "do the fix"
    }

    private static func normalize(_ userMessage: String) -> String {
        userMessage
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func contextSummary(from context: DexterContext) -> String {
        let activeApplicationName = context.activeApplication.localizedName ?? "unknown app"
        let activeWindowTitle = context.activeWindow.title ?? "unknown window"
        return "Active app: \(activeApplicationName). Active window: \(activeWindowTitle)."
    }
}
