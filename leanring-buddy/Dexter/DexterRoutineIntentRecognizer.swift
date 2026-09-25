//
//  DexterRoutineIntentRecognizer.swift
//  leanring-buddy
//

import Foundation

enum DexterRoutineIntentRecognizer {
    static func shouldOpenRoutineCreationFlow(for message: String) -> Bool {
        let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        let creationPhrases = [
            "create a routine",
            "make a routine",
            "set up a routine",
            "automate this",
            "handle this automatically"
        ]
        if creationPhrases.contains(where: { normalized.contains($0) }) {
            return true
        }

        if normalized.hasPrefix("every ") && normalized.count > 12 {
            return true
        }
        if normalized.contains("every morning") || normalized.contains("every monday") {
            return true
        }
        if normalized.contains("when i open ") || normalized.contains("when i launch ") {
            return true
        }
        return false
    }
}
