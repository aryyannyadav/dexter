//
//  DexterMemoryIntentProcessor.swift
//  leanring-buddy
//

import Foundation

/// Applies only explicit user memory intents. Does not infer or auto-save ambient context.
enum DexterMemoryIntentProcessor {
    static func applyExplicitIntents(fromUserMessage userMessage: String, to memoryStore: MemoryStore) {
        let normalizedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else { return }

        if let rememberedFact = extractRememberedFact(from: normalizedMessage) {
            memoryStore.rememberFact(rememberedFact, title: nil, provenance: .explicitUserRequest)
        }

        if let preference = extractUserPreference(from: normalizedMessage) {
            memoryStore.saveUserPreference(
                title: preference.title,
                content: preference.content,
                provenance: .intentionalPreference
            )
        }

        if matchesClearActiveTask(normalizedMessage) {
            memoryStore.setActiveTask(description: nil, provenance: .explicitUserRequest)
        } else if let activeTaskDescription = extractActiveTaskDescription(from: normalizedMessage) {
            memoryStore.setActiveTask(description: activeTaskDescription, provenance: .explicitUserRequest)
        }

        if matchesClearWorkflowContext(normalizedMessage) {
            memoryStore.setWorkflowContext(nil, provenance: .workflowRequired)
        } else if let workflowSummary = extractWorkflowContextSummary(from: normalizedMessage) {
            memoryStore.setWorkflowContext(
                DexterWorkflowContextState(summary: workflowSummary),
                provenance: .workflowRequired
            )
        }
    }

    private static func extractRememberedFact(from message: String) -> String? {
        let prefixes = [
            "remember that ",
            "remember this ",
            "remember: ",
            "don't forget that ",
            "dont forget that ",
            "keep in mind that ",
            "save this to memory: ",
            "save to memory: "
        ]
        return extractSuffix(afterAnyPrefix: prefixes, in: message)
    }

    private static func extractUserPreference(from message: String) -> (title: String, content: String)? {
        if let suffix = extractSuffix(afterAnyPrefix: ["my preference is "], in: message) {
            return (title: "Preference", content: suffix)
        }
        if let suffix = extractSuffix(afterAnyPrefix: ["i prefer "], in: message) {
            return (title: "Preference", content: suffix)
        }
        if let suffix = extractSuffix(afterAnyPrefix: ["always use "], in: message) {
            return (title: "Model preference", content: "Always use \(suffix)")
        }
        return nil
    }

    private static func extractActiveTaskDescription(from message: String) -> String? {
        let prefixes = [
            "my current task is ",
            "current task is ",
            "my task is ",
            "set my task to ",
            "set task to ",
            "i am working on ",
            "i'm working on "
        ]
        return extractSuffix(afterAnyPrefix: prefixes, in: message)
    }

    private static func matchesClearActiveTask(_ message: String) -> Bool {
        let normalized = message.lowercased()
        let phrases = [
            "clear my task",
            "forget my task",
            "end my current task",
            "i finished my task"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    private static func extractWorkflowContextSummary(from message: String) -> String? {
        let prefixes = [
            "workflow context: ",
            "workflow context is ",
            "for this workflow, ",
            "we are in a workflow: ",
            "we're in a workflow: "
        ]
        return extractSuffix(afterAnyPrefix: prefixes, in: message)
    }

    private static func matchesClearWorkflowContext(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("clear workflow context") || normalized.contains("end this workflow")
    }

    private static func extractSuffix(afterAnyPrefix prefixes: [String], in message: String) -> String? {
        let lowercasedMessage = message.lowercased()
        for prefix in prefixes {
            if lowercasedMessage.hasPrefix(prefix) {
                let startIndex = message.index(message.startIndex, offsetBy: prefix.count)
                let suffix = String(message[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return suffix.isEmpty ? nil : suffix
            }
        }
        return nil
    }
}
