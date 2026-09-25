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
    var includePersonalContextGraph: Bool
}

enum DexterContextRelevancePlanner {
    static func shouldRequestScreenCapture(forUserMessage userMessage: String) -> Bool {
        DexterFastRequestRouter.requiresScreenContext(forUserMessage: userMessage)
    }

    static func shouldSkipScreenCapture(forUserMessage userMessage: String) -> Bool {
        !shouldRequestScreenCapture(forUserMessage: userMessage)
    }

    /// Pointer-invocation turns always include captured screen + environment context.
    static func planForPointAtInvocation(context: DexterContext) -> DexterContextRelevancePlan {
        let hasScreenCaptures = context.screen.captureAvailability == .available
            && (context.screen.primaryScreenshot != nil || !context.screen.allScreens.isEmpty)
        let hasSelectedText = {
            guard let selectedText = context.selectedText.selectedText else { return false }
            return !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()

        return DexterContextRelevancePlan(
            includeActiveApplication: true,
            includeActiveWindow: true,
            includePointerContext: true,
            includeScreenContext: hasScreenCaptures,
            includeSelectedText: hasSelectedText,
            includeRecentConversationInPrompt: false,
            includeRecentConversationInAPIHistory: true,
            includeCurrentTask: false,
            includePersistentMemory: context.persistentMemory.hasAnyPersistentMemory,
            includePersonalContextGraph: !(context.personalContextGraph?.entities.isEmpty ?? true)
        )
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
        let includePersonalContextGraph = DexterPersonalContextIntentRecognizer.isPersonalContextQuery(userMessage)
            || !(context.personalContextGraph?.entities.isEmpty ?? true)

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
                includePersistentMemory: hasPersistentMemory,
                includePersonalContextGraph: includePersonalContextGraph
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
                includePersistentMemory: hasPersistentMemory,
                includePersonalContextGraph: includePersonalContextGraph
            )
        }

        if isVisualDeictic {
            return DexterContextRelevancePlan(
                includeActiveApplication: false,
                includeActiveWindow: true,
                includePointerContext: true,
                includeScreenContext: hasScreenCaptures,
                includeSelectedText: hasSelectedText,
                includeRecentConversationInPrompt: false,
                includeRecentConversationInAPIHistory: false,
                includeCurrentTask: false,
                includePersistentMemory: hasPersistentMemory,
                includePersonalContextGraph: includePersonalContextGraph
            )
        }

        return DexterContextRelevancePlan(
            includeActiveApplication: false,
            includeActiveWindow: false,
            includePointerContext: false,
            includeScreenContext: false,
            includeSelectedText: false,
            includeRecentConversationInPrompt: false,
            includeRecentConversationInAPIHistory: true,
            includeCurrentTask: hasCurrentTask,
            includePersistentMemory: hasPersistentMemory,
            includePersonalContextGraph: includePersonalContextGraph
        )
    }

    private static func matchesExplainWindow(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "explain this window",
            "explain the window",
            "what's on my screen",
            "what is on my screen",
            "explain what's on my screen",
            "explain what is on my screen",
            "look at my screen",
            "see my screen"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
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

    static func matchesConversationRecallPublic(_ normalizedMessage: String) -> Bool {
        matchesConversationRecall(normalizedMessage)
    }

    static func matchesErrorDebuggingPublic(_ normalizedMessage: String) -> Bool {
        matchesErrorDebugging(normalizedMessage)
    }

    static func matchesExplainWindowPublic(_ normalizedMessage: String) -> Bool {
        matchesExplainWindow(normalizedMessage)
    }

    static func matchesHypotheticalControlQuestionPublic(_ normalizedMessage: String) -> Bool {
        matchesHypotheticalControlQuestion(normalizedMessage)
    }

    private static func matchesWhatIsThis(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "what is this",
            "what's this",
            "what is that",
            "what's that",
            "what am i looking at",
            "what's this button",
            "what is this button",
            "what's that button",
            "how do i use this",
            "how do i use that",
            "do this"
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
