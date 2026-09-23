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

        if let applicationName = openApplicationName(from: normalizedMessage) {
            return .action(
                DexterActionFactory.openApplication(
                    named: applicationName,
                    contextSummary: contextSummary(from: context)
                )
            )
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
            message: "Dexter can explain what you're pointing at, open Safari or VS Code, apply a taught code fix, or click the control under your pointer (say enable it)."
        )
    }

    private static func openApplicationName(from normalizedMessage: String) -> String? {
        let openPhrases = [
            "open vscode",
            "open vs code",
            "open visual studio code",
            "launch vscode",
            "open safari",
            "open the safari app",
            "please open safari",
            "open safari for me"
        ]
        guard openPhrases.contains(where: { normalizedMessage.contains($0) || normalizedMessage == $0 }) else {
            return nil
        }
        return DexterDemoApplicationNames.canonicalName(for: normalizedMessage)
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
