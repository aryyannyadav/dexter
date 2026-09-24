//
//  DexterMemoryIntentProcessor.swift
//  leanring-buddy
//

import Foundation

/// Explicit user memory intents only. Inferred memory never auto-saves here.
enum DexterMemoryIntentProcessor {
    static func process(fromUserMessage userMessage: String, memoryStore: MemoryStore) -> DexterMemoryIntentOutcome {
        let normalizedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else { return .noMemoryIntent }

        if matchesMemoryRecall(normalizedMessage) {
            let summary = DexterMemoryEngine.summaryForRecall(from: memoryStore.allStructuredMemories())
            return .userFacingResponse(summary)
        }

        if let forgetQuery = extractForgetTarget(from: normalizedMessage) {
            var memories = memoryStore.allStructuredMemories()
            let didForget = DexterMemoryEngine.forget(matching: forgetQuery, in: &memories)
            if didForget {
                persist(memories: memories, memoryStore: memoryStore)
                return .userFacingResponse("Okay — I forgot what matched “\(forgetQuery)”.")
            }
            return .userFacingResponse("I couldn't find an active memory matching “\(forgetQuery)”.")
        }

        if let update = extractMemoryUpdate(from: normalizedMessage) {
            var memories = memoryStore.allStructuredMemories()
            let didUpdate = DexterMemoryEngine.update(
                matching: update.matchQuery,
                newContent: update.newContent,
                in: &memories
            )
            if didUpdate {
                persist(memories: memories, memoryStore: memoryStore)
                return .userFacingResponse("Updated that memory.")
            }
            return .userFacingResponse("I couldn't find a memory to update for “\(update.matchQuery)”.")
        }

        if normalizedMessage.lowercased() == "yes remember that"
            || normalizedMessage.lowercased() == "yes, remember that" {
            return .appliedSilently
        }

        if let rememberedFact = extractRememberedFact(from: normalizedMessage) {
            switch DexterMemoryContentPolicy.evaluateForStorage(rememberedFact, source: .explicitUserUtterance) {
            case .rejected(let reason):
                return .userFacingResponse(reason)
            case .allowed:
                memoryStore.rememberFact(rememberedFact, title: nil, provenance: .explicitUserRequest)
                return .appliedSilently
            }
        }

        if let preference = extractUserPreference(from: normalizedMessage) {
            switch DexterMemoryContentPolicy.evaluateForStorage(preference.content, source: .explicitUserUtterance) {
            case .rejected(let reason):
                return .userFacingResponse(reason)
            case .allowed:
                memoryStore.saveUserPreference(
                    title: preference.title,
                    content: preference.content,
                    provenance: .intentionalPreference
                )
                return .appliedSilently
            }
        }

        if matchesClearActiveTask(normalizedMessage) {
            memoryStore.setActiveTask(description: nil, provenance: .explicitUserRequest)
            return .appliedSilently
        } else if let activeTaskDescription = extractActiveTaskDescription(from: normalizedMessage) {
            memoryStore.setActiveTask(description: activeTaskDescription, provenance: .explicitUserRequest)
            return .appliedSilently
        }

        if matchesClearWorkflowContext(normalizedMessage) {
            memoryStore.setWorkflowContext(nil, provenance: .workflowRequired)
            return .appliedSilently
        } else if let workflowSummary = extractWorkflowContextSummary(from: normalizedMessage) {
            memoryStore.setWorkflowContext(
                DexterWorkflowContextState(summary: workflowSummary),
                provenance: .workflowRequired
            )
            return .appliedSilently
        }

        return .noMemoryIntent
    }

    static func applyExplicitIntents(fromUserMessage userMessage: String, to memoryStore: MemoryStore) {
        _ = process(fromUserMessage: userMessage, memoryStore: memoryStore)
    }

    private static func persist(memories: [DexterStructuredMemoryRecord], memoryStore: MemoryStore) {
        memoryStore.replaceStructuredMemories(memories)
    }

    private static func matchesMemoryRecall(_ message: String) -> Bool {
        let normalized = message.lowercased()
        let phrases = [
            "what do you remember",
            "what do you know about me",
            "show my memories",
            "list my memories",
            "what have you remembered"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    private static func extractForgetTarget(from message: String) -> String? {
        let prefixes = [
            "forget this",
            "forget that",
            "forget about ",
            "delete this memory",
            "remove this memory",
            "don't remember "
        ]
        if let suffix = extractSuffix(afterAnyPrefix: prefixes, in: message) {
            return suffix
        }
        if message.lowercased() == "forget this" || message.lowercased() == "forget that" {
            return message
        }
        return nil
    }

    private static func extractMemoryUpdate(from message: String) -> (matchQuery: String, newContent: String)? {
        let prefixes = ["update that to ", "update this to ", "change that to ", "change this to "]
        for prefix in prefixes {
            if let suffix = extractSuffix(afterAnyPrefix: [prefix], in: message) {
                let parts = suffix.split(separator: ":", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    return (matchQuery: parts[0].trimmingCharacters(in: .whitespaces), newContent: parts[1].trimmingCharacters(in: .whitespaces))
                }
                return (matchQuery: "", newContent: suffix)
            }
        }
        return nil
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
