//
//  DexterActionRecoveryEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterActionRecoveryIntentRecognizer {
    static func recognizeRetry(fromUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let phrases = [
            "retry the last computer action",
            "retry last computer action",
            "retry the last action",
            "retry last action",
            "please retry the last computer action",
            "try again",
            "try that again",
            "do that again",
            "retry the previous action",
            "try the previous action again"
        ]
        return phrases.contains { normalized == $0 || normalized.contains($0) }
    }

    static func recognizeUndo(fromUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let phrases = [
            "undo last action",
            "undo that",
            "undo the last thing",
            "undo last safe action",
            "roll back last action",
            "revert last action"
        ]
        return phrases.contains { normalized.contains($0) }
    }
}

enum DexterActionRecoveryEngine {
    static func rollbackAction(for metadata: DexterActionRecoveryMetadata) -> DexterAction? {
        guard metadata.reversible else { return nil }

        switch metadata.rollbackStrategy {
        case .none:
            return nil

        case .notSupported:
            return nil

        case .focusPreviousApplication(let applicationName):
            return DexterActionFactory.focusApplication(
                named: applicationName,
                contextSummary: "Undo: return focus to \(applicationName)."
            )

        case .openPreviousBrowserURL(let url, let verificationHint):
            return DexterActionFactory.browserOpen(url: url, verificationHint: verificationHint)
        }
    }

    static func userFacingUndoPlan(entry: DexterActionRecoveryLedgerEntry) -> String {
        let metadata = entry.metadata
        guard metadata.reversible, let rollbackAction = rollbackAction(for: metadata) else {
            return DexterActionRecoveryCopy.undoUnavailableMessage(for: metadata)
        }

        var lines = [
            "I can undo the last safe Dexter action by reversing its semantic state—not by replaying stale coordinates."
        ]
        if let before = metadata.beforeState?.summary.nonEmptyTrimmedValue {
            lines.append("Before: \(before).")
        }
        if let after = metadata.afterState?.summary.nonEmptyTrimmedValue {
            lines.append("After: \(after).")
        }
        lines.append("Rollback step: \(rollbackAction.humanReadableDescription)")
        return lines.joined(separator: " ")
    }
}
