//
//  DexterIntentRouter.swift
//  leanring-buddy
//

import Foundation

enum DexterIntentRouter {
    static let minimumConfidenceToActWithoutClarification: Double = 0.72

    static func recognize(userMessage: String, context: DexterContext?) -> DexterStructuredIntent {
        let normalizedMessage = normalize(userMessage)

        if let lifecycleIntent = DexterApplicationLifecycleIntentParser.parse(from: normalizedMessage) {
            switch lifecycleIntent.operation {
            case .launch:
                return DexterStructuredIntent(
                    kind: .open,
                    target: .application(lifecycleIntent.applicationName),
                    confidence: 0.94,
                    normalizedUserMessage: normalizedMessage
                )
            case .focus:
                return DexterStructuredIntent(
                    kind: .focus,
                    target: .application(lifecycleIntent.applicationName),
                    confidence: 0.92,
                    normalizedUserMessage: normalizedMessage
                )
            case .quit:
                return DexterStructuredIntent(
                    kind: .close,
                    target: .application(lifecycleIntent.applicationName),
                    confidence: 0.94,
                    normalizedUserMessage: normalizedMessage
                )
            }
        }

        if matchesRememberIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .remember,
                target: .freeText(userMessage),
                confidence: 0.9,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesForgetIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .forget,
                target: .freeText(userMessage),
                confidence: 0.88,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesRemindIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .remind,
                target: .freeText(userMessage),
                confidence: 0.82,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesTroubleshootSignal(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .fix,
                target: .currentContext,
                confidence: 0.88,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesFixIntent(normalizedMessage) {
            let hasErrorSignal = normalizedMessage.contains("error")
                || normalizedMessage.contains("exception")
                || normalizedMessage.contains("failed")
                || normalizedMessage.contains("bug")
            let confidence = hasErrorSignal || normalizedMessage.contains("fix it") ? 0.9 : 0.58
            return DexterStructuredIntent(
                kind: .fix,
                target: .currentContext,
                confidence: confidence,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesAutomateIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .automate,
                target: .currentContext,
                confidence: 0.86,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesRunIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .run,
                target: .currentContext,
                confidence: 0.84,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesPlanIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .plan,
                target: .currentContext,
                confidence: 0.83,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesSearchIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .search,
                target: .freeText(userMessage),
                confidence: 0.85,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesCreateIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .create,
                target: .currentContext,
                confidence: 0.8,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesEditIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .edit,
                target: .currentContext,
                confidence: 0.79,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesSummarizeIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .summarize,
                target: .currentContext,
                confidence: 0.84,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesCompareIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .compare,
                target: .currentContext,
                confidence: 0.82,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesFindIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .find,
                target: .currentContext,
                confidence: 0.8,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesTeachIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .teach,
                target: .currentContext,
                confidence: 0.88,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesExplainIntent(normalizedMessage, context: context) {
            let usesPointer = DexterPointerControlWorkflow.matchesPointerExplainIntent(normalizedUserMessage: normalizedMessage)
                || DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedMessage)
            return DexterStructuredIntent(
                kind: .explain,
                target: usesPointer ? .currentPointerTarget : .currentContext,
                confidence: usesPointer ? 0.91 : 0.78,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesPointerActIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .run,
                target: .currentPointerTarget,
                confidence: 0.87,
                normalizedUserMessage: normalizedMessage
            )
        }

        if matchesCompanionIntent(normalizedMessage) {
            return DexterStructuredIntent(
                kind: .companion,
                target: .none,
                confidence: 0.9,
                normalizedUserMessage: normalizedMessage
            )
        }

        return DexterStructuredIntent(
            kind: .ask,
            target: .none,
            confidence: normalizedMessage.isEmpty ? 0.3 : 0.62,
            normalizedUserMessage: normalizedMessage
        )
    }

    private static func normalize(_ userMessage: String) -> String {
        userMessage
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesRememberIntent(_ normalizedMessage: String) -> Bool {
        let prefixes = ["remember that ", "remember this ", "remember: ", "save to memory", "keep in mind"]
        return prefixes.contains { normalizedMessage.contains($0) }
    }

    private static func matchesForgetIntent(_ normalizedMessage: String) -> Bool {
        let phrases = ["forget that ", "forget this ", "remove from memory", "delete from memory", "forget my "]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesRemindIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("remind me")
    }

    private static func matchesTroubleshootSignal(_ normalizedMessage: String) -> Bool {
        let troubleshootPhrases = [
            "troubleshoot",
            "debug",
            "what went wrong",
            "what's wrong here",
            "whats wrong here",
            "why is this error",
            "why isn't this working",
            "why is this not working",
            "not working"
        ]
        if troubleshootPhrases.contains(where: { normalizedMessage.contains($0) }) {
            return true
        }
        let hasErrorSignal = normalizedMessage.contains("error")
            || normalizedMessage.contains("exception")
            || normalizedMessage.contains("failed")
            || normalizedMessage.contains("crash")
        let hasWhy = normalizedMessage.contains("why ")
        return hasErrorSignal && hasWhy
    }

    private static func matchesFixIntent(_ normalizedMessage: String) -> Bool {
        if normalizedMessage == "fix it" || normalizedMessage == "fix it for me" || normalizedMessage == "apply the fix" {
            return true
        }
        return normalizedMessage.contains("fix this") || normalizedMessage.contains("fix the")
    }

    private static func matchesAutomateIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("automate") || normalizedMessage.contains("workflow for me")
    }

    private static func matchesRunIntent(_ normalizedMessage: String) -> Bool {
        let phrases = ["run this", "execute this", "do this for me", "take action", "perform this"]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesPlanIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("make a plan") || normalizedMessage.contains("plan how") || normalizedMessage == "plan"
    }

    private static func matchesSearchIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.hasPrefix("search for ") || normalizedMessage.hasPrefix("search ") || normalizedMessage.contains("look up ")
    }

    private static func matchesCreateIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.hasPrefix("create ") || normalizedMessage.hasPrefix("make a new ")
    }

    private static func matchesEditIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.hasPrefix("edit ") || normalizedMessage.contains("change this to")
    }

    private static func matchesSummarizeIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("summarize") || normalizedMessage.contains("summary of")
    }

    private static func matchesCompareIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("compare ") || normalizedMessage.contains("difference between")
    }

    private static func matchesFindIntent(_ normalizedMessage: String) -> Bool {
        normalizedMessage.hasPrefix("find ") || normalizedMessage.contains("where is ")
    }

    private static func matchesTeachIntent(_ normalizedMessage: String) -> Bool {
        if DexterPointerControlWorkflow.matchesPointerTeachIntent(normalizedUserMessage: normalizedMessage) {
            return true
        }
        let phrases = ["teach me", "help me learn", "i want to learn", "teach me this", "teach me that"]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesExplainIntent(_ normalizedMessage: String, context: DexterContext?) -> Bool {
        if DexterPointerControlWorkflow.matchesPointerExplainIntent(normalizedUserMessage: normalizedMessage) {
            return true
        }
        let phrases = ["explain", "what does", "what is", "what's", "why does", "why is", "tell me why"]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesPointerActIntent(_ normalizedMessage: String) -> Bool {
        DexterPointerControlWorkflow.matchesPointerActIntent(normalizedUserMessage: normalizedMessage)
            || normalizedMessage.contains("click the")
            || normalizedMessage.contains("click on")
    }

    private static func matchesCompanionIntent(_ normalizedMessage: String) -> Bool {
        let phrases = ["hello", "hi dexter", "hey dexter", "good morning", "good evening", "how are you"]
        return phrases.contains { normalizedMessage == $0 || normalizedMessage.hasPrefix($0 + " ") }
    }
}
