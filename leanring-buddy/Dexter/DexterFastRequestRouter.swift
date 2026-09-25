//
//  DexterFastRequestRouter.swift
//  leanring-buddy
//

import Foundation

/// High-level turn routing (deterministic heuristics — no model call).
enum DexterRequestRoute: String, Equatable {
    case fastChat = "fast_chat"
    case screenContext = "screen_context"
    case computerAction = "computer_action"
    case integrationAgent = "integration_agent"
    case teaching = "teaching"
}

struct DexterRequestRoutingDecision: Equatable {
    let route: DexterRequestRoute
    let requiresScreenCapture: Bool
    let pinPointerForContext: Bool
    let contextPerformanceProfile: DexterContextPerformanceProfile
}

enum DexterFastRequestRouter {
    static func route(
        userMessage: String,
        hasPointInvokeScreenCaptures: Bool = false,
        forcePointInvokeScreenRoute: Bool = false
    ) -> DexterRequestRoutingDecision {
        let trimmedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedMessage = trimmedMessage.lowercased()

        if forcePointInvokeScreenRoute || hasPointInvokeScreenCaptures {
            if matchesTeachingIntent(normalizedMessage) {
                return teachingDecision(requiresScreen: true)
            }
            return screenContextDecision(pinPointer: true)
        }

        if matchesComputerActionRoute(userMessage: trimmedMessage, normalizedMessage: normalizedMessage) {
            return DexterRequestRoutingDecision(
                route: .computerAction,
                requiresScreenCapture: false,
                pinPointerForContext: false,
                contextPerformanceProfile: .minimal
            )
        }

        if matchesIntegrationAgentRoute(normalizedMessage) {
            return DexterRequestRoutingDecision(
                route: .integrationAgent,
                requiresScreenCapture: false,
                pinPointerForContext: false,
                contextPerformanceProfile: .standard
            )
        }

        if matchesTeachingIntent(normalizedMessage) {
            let needsScreen = matchesTeachingRequiresScreen(normalizedMessage)
            return teachingDecision(requiresScreen: needsScreen)
        }

        if requiresScreenContext(forNormalizedMessage: normalizedMessage) {
            return screenContextDecision(pinPointer: true)
        }

        if DexterTrivialQuestionClassifier.isTrivialQuestion(trimmedMessage)
            || matchesFastChatGreeting(normalizedMessage) {
            return fastChatDecision()
        }

        if matchesGeneralKnowledgeWithoutScreen(normalizedMessage) {
            return fastChatDecision()
        }

        return DexterRequestRoutingDecision(
            route: .fastChat,
            requiresScreenCapture: false,
            pinPointerForContext: false,
            contextPerformanceProfile: .standard
        )
    }

    /// Shared screen-context detector (avoids false positives like “explain this concept”).
    static func requiresScreenContext(forUserMessage userMessage: String) -> Bool {
        let normalizedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return requiresScreenContext(forNormalizedMessage: normalizedMessage)
    }

    private static func fastChatDecision() -> DexterRequestRoutingDecision {
        DexterRequestRoutingDecision(
            route: .fastChat,
            requiresScreenCapture: false,
            pinPointerForContext: false,
            contextPerformanceProfile: .minimal
        )
    }

    private static func screenContextDecision(pinPointer: Bool) -> DexterRequestRoutingDecision {
        DexterRequestRoutingDecision(
            route: .screenContext,
            requiresScreenCapture: true,
            pinPointerForContext: pinPointer,
            contextPerformanceProfile: .standard
        )
    }

    private static func teachingDecision(requiresScreen: Bool) -> DexterRequestRoutingDecision {
        DexterRequestRoutingDecision(
            route: .teaching,
            requiresScreenCapture: requiresScreen,
            pinPointerForContext: requiresScreen,
            contextPerformanceProfile: requiresScreen ? .standard : .minimal
        )
    }

    private static func requiresScreenContext(forNormalizedMessage normalizedMessage: String) -> Bool {
        if matchesAbstractConceptReference(normalizedMessage) {
            return false
        }
        if DexterContextRelevancePlanner.matchesExplainWindowPublic(normalizedMessage) {
            return true
        }
        if DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedMessage) {
            return true
        }
        if DexterContextRelevancePlanner.matchesErrorDebuggingPublic(normalizedMessage) {
            return true
        }
        if DexterContextRelevancePlanner.matchesHypotheticalControlQuestionPublic(normalizedMessage) {
            return true
        }
        if matchesUIDeicticReference(normalizedMessage) {
            return true
        }
        if matchesScreenExplicitPhrases(normalizedMessage) {
            return true
        }
        return false
    }

    private static func matchesFastChatGreeting(_ normalizedMessage: String) -> Bool {
        let trimmedGreeting = normalizedMessage.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,"))
        let greetings = [
            "hey", "hello", "hi", "hi dexter", "thanks", "thank you",
            "what's up", "whats up", "how are you", "good morning", "good evening"
        ]
        return greetings.contains { trimmedGreeting == $0 || trimmedGreeting.hasPrefix($0 + " ") }
    }

    private static func matchesGeneralKnowledgeWithoutScreen(_ normalizedMessage: String) -> Bool {
        let prefixes = [
            "what is ", "what's ", "who is ", "define ", "explain ", "how do i ",
            "write a ", "summarize ", "draft a ", "compare "
        ]
        guard prefixes.contains(where: { normalizedMessage.hasPrefix($0) }) else {
            return false
        }
        return !requiresScreenContext(forNormalizedMessage: normalizedMessage)
    }

    private static func matchesAbstractConceptReference(_ normalizedMessage: String) -> Bool {
        let abstractPhrases = [
            "this concept", "this idea", "this approach", "this method", "this topic",
            "this definition", "this term", "this pattern", "this principle", "this theory",
            "this algorithm", "this constructor", "this class", "this struct", "this protocol",
            "polymorphism", "recursion", "inheritance"
        ]
        return abstractPhrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesUIDeicticReference(_ normalizedMessage: String) -> Bool {
        let uiAnchoredPhrases = [
            "this button", "that button", "this field", "that field", "this toggle",
            "this menu", "this dialog", "this window", "this tab", "this panel",
            "this error", "this warning", "this message", "this code", "this line",
            "under my cursor", "under the cursor", "pointing at", "on screen", "on my screen"
        ]
        return uiAnchoredPhrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesScreenExplicitPhrases(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "what's on my screen", "what is on my screen", "look at my screen",
            "see my screen", "my screen", "screenshot"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesTeachingIntent(_ normalizedMessage: String) -> Bool {
        let phrases = [
            "teach me", "show me how", "walk me through", "guide me through",
            "step by step", "what do i click", "where do i click", "what should i click"
        ]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesTeachingRequiresScreen(_ normalizedMessage: String) -> Bool {
        if normalizedMessage.contains("recursion") || normalizedMessage.contains("polymorphism") {
            return false
        }
        if matchesUIDeicticReference(normalizedMessage) {
            return true
        }
        if normalizedMessage.contains("click") || normalizedMessage.contains("screen") {
            return true
        }
        return normalizedMessage.contains("walk me through")
            || normalizedMessage.contains("what do i click")
            || normalizedMessage.contains("where do i click")
    }

    private static func matchesIntegrationAgentRoute(_ normalizedMessage: String) -> Bool {
        let integrationSignals = [
            "check my gmail", "check my email", "read my email", "my inbox",
            "notion page", "notion doc", "create a notion", "linear issue", "update linear",
            "calendar event", "my calendar", "google calendar", "slack message",
            "research and save", "save to notion", "create a ticket"
        ]
        return integrationSignals.contains { normalizedMessage.contains($0) }
    }

    private static func matchesComputerActionRoute(userMessage: String, normalizedMessage: String) -> Bool {
        let structuredIntent = DexterIntentRouter.recognize(userMessage: userMessage, context: nil)
        switch structuredIntent.kind {
        case .open, .close, .focus, .run:
            return structuredIntent.confidence >= DexterIntentRouter.minimumConfidenceToActWithoutClarification
        default:
            break
        }

        if DexterBrowserIntelligencePlanner.isExecutableSearchUtterance(normalizedUserMessage: normalizedMessage) {
            return true
        }

        let directActionPhrases = [
            "scroll down", "scroll up", "scroll left", "scroll right",
            "click this", "click that", "type this", "type that", "press enter",
            "send this", "quit ", "kill ", "close calculator", "open safari", "open whatsapp"
        ]
        return directActionPhrases.contains { normalizedMessage.contains($0) }
    }
}
