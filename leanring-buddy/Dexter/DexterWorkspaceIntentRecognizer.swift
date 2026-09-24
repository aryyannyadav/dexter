//
//  DexterWorkspaceIntentRecognizer.swift
//  leanring-buddy
//

import Foundation

enum DexterWorkspaceIntentRecognizer {
    static func recognizeSave(fromUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return matchesAny(normalized, phrases: [
            "save my workspace",
            "snapshot my workspace",
            "remember this workspace",
            "capture my workspace",
            "save workspace"
        ])
    }

    static func recognizeRestore(fromUserMessage userMessage: String) -> Bool {
        let normalized = userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return matchesAny(normalized, phrases: [
            "restore my workspace",
            "bring back my workspace",
            "restore workspace",
            "resume my workspace",
            "put my workspace back"
        ])
    }

    private static func matchesAny(_ normalizedMessage: String, phrases: [String]) -> Bool {
        phrases.contains { phrase in
            normalizedMessage.contains(phrase)
        }
    }
}
