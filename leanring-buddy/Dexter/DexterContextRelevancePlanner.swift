//
//  DexterContextRelevancePlanner.swift
//  leanring-buddy
//

import Foundation

struct DexterContextRelevancePlan: Equatable {
    var includeActiveApplication: Bool
    var includeActiveWindow: Bool
    var includePointerContext: Bool
    var includeScreenContext: Bool
    var includeSelectedText: Bool
    var includeRecentConversationInPrompt: Bool
    var includeRecentConversationInAPIHistory: Bool
    var includeCurrentTask: Bool
    var includePersistentMemory: Bool
}

enum DexterContextRelevancePlanner {
    static func shouldSkipScreenCapture(forUserMessage userMessage: String) -> Bool {
        let normalizedMessage = userMessage.lowercased()
        let isConversationRecall = matchesConversationRecall(normalizedMessage)
        let needsVisualContext = matchesVisualDeictic(normalizedMessage)
            || matchesWhatIsThis(normalizedMessage)
            || matchesHypotheticalControlQuestion(normalizedMessage)
            || matchesErrorDebugging(normalizedMessage)
        return isConversationRecall && !needsVisualContext
    }

    static func plan(forUserMessage userMessage: String, context: DexterContext) -> DexterContextRelevancePlan {
        let normalizedMessage = userMessage.lowercased()

        let isConversationRecall = matchesConversationRecall(normalizedMessage)
        let isVisualDeictic = matchesVisualDeictic(normalizedMessage)
            || matchesWhatIsThis(normalizedMessage)
            || matchesHypotheticalControlQuestion(normalizedMessage)
        let isErrorDebugging = matchesErrorDebugging(normalizedMessage)

        let hasScreenCaptures = context.screen.captureAvailability == .available && !context.screen.allScreens.isEmpty
        let hasSelectedText = {
            guard let selectedText = context.selectedText.selectedText else { return false }
            return !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()
        let hasCurrentTask = {
            if context.currentTask.activeWorkflowTask != nil {
                return true
            }
            guard let taskDescription = context.currentTask.currentTaskDescription else { return false }
            return !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()
        let hasPersistentMemory = context.persistentMemory.hasAnyPersistentMemory

        if isConversationRecall && !isVisualDeictic && !isErrorDebugging {
            return DexterContextRelevancePlan(
                includeActiveApplication: false,
                includeActiveWindow: false,
                includePointerContext: false,
                includeScreenContext: false,
                includeSelectedText: false,
                includeRecentConversationInPrompt: true,
                includeRecentConversationInAPIHistory: true,
                includeCurrentTask: false,
                includePersistentMemory: hasPersistentMemory
            )
        }

        if isErrorDebugging {
            return DexterContextRelevancePlan(
                includeActiveApplication: true,
                includeActiveWindow: true,
                includePointerContext: hasScreenCaptures,
                includeScreenContext: hasScreenCaptures,
                includeSelectedText: hasSelectedText,
                includeRecentConversationInPrompt: false,
                includeRecentConversationInAPIHistory: true,
                includeCurrentTask: hasCurrentTask,
                includePersistentMemory: hasPersistentMemory
            )
        }

        if isVisualDeictic {
            return DexterContextRelevancePlan(
                includeActiveApplication: false,
                includeActiveWindow: true,
                includePointerContext: hasScreenCaptures,
                includeScreenContext: hasScreenCaptures,
                includeSelectedText: hasSelectedText,
                includeRecentConversationInPrompt: false,
                includeRecentConversationInAPIHistory: false,
                includeCurrentTask: false,
                includePersistentMemory: hasPersistentMemory
            )
        }

        return DexterContextRelevancePlan(
            includeActiveApplication: hasScreenCaptures,
            includeActiveWindow: hasScreenCaptures,
            includePointerContext: hasScreenCaptures,
            includeScreenContext: hasScreenCaptures,
            includeSelectedText: hasSelectedText && isErrorDebugging,
            includeRecentConversationInPrompt: false,
            includeRecentConversationInAPIHistory: true,
            includeCurrentTask: hasCurrentTask,
            includePersistentMemory: hasPersistentMemory
        )
    }

    private static func matchesConversationRecall(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "what did you tell me",
            "what did you say",
            "you told me",
            "you said earlier",
            "earlier you",
            "before you said",
            "remember when",
            "last time you",
            "from earlier",
            "what was your answer"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    static func matchesWhatIsThisPublic(_ normalizedMessage: String) -> Bool {
        matchesWhatIsThis(normalizedMessage)
    }

    private static func matchesWhatIsThis(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "what is this",
            "what's this",
            "what is that",
            "what's that",
            "what am i looking at"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesHypotheticalControlQuestion(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "what happens if i enable",
            "what happens if i turn on",
            "what happens if i click",
            "what happens if i toggle",
            "what would happen if i enable",
            "what would happen if i turn on"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesVisualDeictic(_ normalizedMessage: String) -> Bool {
        let phrases = [
            " this",
            " that",
            " here",
            " on screen",
            " on my screen",
            " look at",
            " pointing at",
            " under my cursor",
            " under the cursor",
            " find something interesting"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesErrorDebugging(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "error",
            "exception",
            "failed",
            "failure",
            "why is this",
            "why isn't",
            "why is it",
            "what went wrong",
            "what's wrong",
            "whats wrong",
            "debug",
            "bug",
            "issue",
            "crash",
            "stack trace"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }
}
