//
//  DexterHubMemoryMomentReporter.swift
//  leanring-buddy
//
//  Maps existing Dexter memory intents / retrieval to Hub presentation events.
//

import Foundation

@MainActor
enum DexterHubMemoryMomentReporter {
    private static weak var eventBridge: DexterHubEventBridge?
    private static var lastBroadcastProjectName: String?

    static func register(eventBridge: DexterHubEventBridge) {
        self.eventBridge = eventBridge
    }

    static func reportMemoryIntentOutcome(
        _ outcome: DexterMemoryIntentOutcome,
        userMessage: String,
        memoryStore: MemoryStore
    ) {
        switch outcome {
        case .appliedSilently:
            if let savedSummary = extractExplicitRememberSummary(from: userMessage) {
                let recordId = newestSavedRecordIdentifier(matchingSummary: savedSummary, memoryStore: memoryStore)
                eventBridge?.broadcastMemorySave(summary: savedSummary, memoryRecordId: recordId)
            }
        case .userFacingResponse(let responseText):
            if matchesExplicitMemoryRecall(userMessage) {
                let snippet = extractRecallSnippet(from: responseText)
                eventBridge?.broadcastMemoryRecall(summary: snippet, memoryRecordId: nil, preferenceReflection: nil)
            }
        case .noMemoryIntent, .inferenceConfirmationPrompt:
            break
        }
    }

    static func reportContextualRecallIfAppropriate(
        userMessage: String,
        memoryIntentOutcome: DexterMemoryIntentOutcome,
        retrievedMemories: [DexterStructuredMemoryRecord]
    ) {
        switch memoryIntentOutcome {
        case .userFacingResponse, .appliedSilently:
            return
        case .noMemoryIntent, .inferenceConfirmationPrompt:
            break
        }

        guard let matchedMemory = matchedContextualMemory(
            userMessage: userMessage,
            retrievedMemories: retrievedMemories
        ) else {
            return
        }
        let snippet = boundHubSafeSummary(matchedMemory.content)
        let preferenceReflection = hubPreferenceReflection(for: matchedMemory)
        eventBridge?.broadcastMemoryRecall(
            summary: snippet,
            memoryRecordId: nil,
            preferenceReflection: preferenceReflection
        )
    }

    static func reportProjectContextIfAvailable(
        profileId: UUID?,
        fileWorkspaceStore: DexterFileWorkspaceStore
    ) {
        guard let profileId,
              let workspace = fileWorkspaceStore.workspace(forProfileId: profileId)
        else {
            return
        }
        let projectName = workspace.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty else { return }
        guard projectName != lastBroadcastProjectName else { return }
        lastBroadcastProjectName = projectName
        eventBridge?.broadcastProjectContext(label: "WORKING ON", projectName: projectName)
    }

    private static func hubPreferenceReflection(for memory: DexterStructuredMemoryRecord) -> String? {
        guard memory.type == .preference else { return nil }
        let normalizedContent = memory.content.lowercased()
        if normalizedContent.contains("concise")
            || normalizedContent.contains("brief")
            || normalizedContent.contains("short answer")
            || normalizedContent.contains("keep it short")
        {
            return "Keeping this concise, like you prefer."
        }
        return nil
    }

    private static func matchedContextualMemory(
        userMessage: String,
        retrievedMemories: [DexterStructuredMemoryRecord]
    ) -> DexterStructuredMemoryRecord? {
        let normalizedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedMessage.count >= 10 else { return nil }
        guard normalizedMessage.contains("?")
            || normalizedMessage.hasPrefix("what ")
            || normalizedMessage.hasPrefix("which ")
            || normalizedMessage.hasPrefix("who ")
            || normalizedMessage.hasPrefix("where ")
            || normalizedMessage.hasPrefix("when ")
            || normalizedMessage.hasPrefix("how ")
        else {
            return nil
        }

        let queryTokens = tokenize(normalizedMessage).filter { $0.count >= 4 }
        guard !queryTokens.isEmpty else { return nil }

        for memory in retrievedMemories.prefix(4) {
            guard memory.permissions.mayIncludeInModelContext else { continue }
            let normalizedContent = memory.content.lowercased()
            let matchedTokenCount = queryTokens.count(where: { normalizedContent.contains($0) })
            if matchedTokenCount >= 1 {
                return memory
            }
        }
        return nil
    }

    private static func newestSavedRecordIdentifier(
        matchingSummary summary: String,
        memoryStore: MemoryStore
    ) -> String? {
        let normalizedSummary = summary.lowercased()
        let match = memoryStore.allStructuredMemories()
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first { record in
                let content = record.content.lowercased()
                return content == normalizedSummary || content.contains(normalizedSummary)
                    || normalizedSummary.contains(content)
            }
        return match?.id.uuidString
    }

    private static func extractExplicitRememberSummary(from userMessage: String) -> String? {
        let rememberPrefixes = [
            "remember that ",
            "remember this ",
            "remember: ",
            "don't forget that ",
            "dont forget that ",
            "keep in mind that ",
            "save this to memory: ",
            "save to memory: "
        ]
        if let suffix = extractSuffix(afterAnyPrefix: rememberPrefixes, in: userMessage) {
            return boundHubSafeSummary(suffix)
        }

        let preferencePrefixes = [
            "my preference is ",
            "i prefer ",
            "always use "
        ]
        if let suffix = extractSuffix(afterAnyPrefix: preferencePrefixes, in: userMessage) {
            return boundHubSafeSummary(suffix)
        }

        return nil
    }

    private static func extractRecallSnippet(from responseText: String) -> String {
        for line in responseText.split(separator: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            if trimmedLine.hasPrefix("- ["), let closingBracket = trimmedLine.firstIndex(of: "]") {
                let afterLabel = trimmedLine[trimmedLine.index(after: closingBracket)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !afterLabel.isEmpty {
                    return boundHubSafeSummary(afterLabel)
                }
            }
            if !trimmedLine.lowercased().hasPrefix("here's what i remember") {
                return boundHubSafeSummary(trimmedLine)
            }
        }
        return boundHubSafeSummary(responseText)
    }

    private static func matchesExplicitMemoryRecall(_ message: String) -> Bool {
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

    private static func tokenize(_ text: String) -> [String] {
        text.split { !$0.isLetter && !$0.isNumber }.map { String($0).lowercased() }
    }

    private static func boundHubSafeSummary(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 120 else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 120)
        return String(trimmed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
