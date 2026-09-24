//
//  DexterContextCollectionPlanner.swift
//  leanring-buddy
//

import Foundation

struct DexterContextCollectionPlan: Equatable {
    let minimumRelevanceLevel: DexterContextRelevanceLevel
    let collectPermissions: Bool
    let collectPointer: Bool
    let collectPointerTarget: Bool
    let collectActiveApplication: Bool
    let collectActiveWindow: Bool
    let collectSelectedText: Bool
    let collectScreenContext: Bool
    let collectClipboard: Bool
    let collectConversation: Bool
    let collectRecentActions: Bool
    let collectCurrentTask: Bool
    let collectMemory: Bool
    let collectProjectContext: Bool
    let collectBrowserContext: Bool
    let collectAvailableTools: Bool
}

enum DexterContextCollectionPlanner {
    static func plan(for request: DexterContextAssemblyRequest) -> DexterContextCollectionPlan {
        if request.performanceProfile == .minimal
            || DexterTrivialQuestionClassifier.isTrivialQuestion(request.userMessage) {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .user,
                collectPermissions: false,
                collectPointer: false,
                collectPointerTarget: false,
                collectActiveApplication: false,
                collectActiveWindow: false,
                collectSelectedText: false,
                collectScreenContext: false,
                collectClipboard: false,
                collectConversation: request.includeRecentConversation,
                collectRecentActions: false,
                collectCurrentTask: true,
                collectMemory: false,
                collectProjectContext: false,
                collectBrowserContext: false,
                collectAvailableTools: false
            )
        }

        let normalizedMessage = request.userMessage.lowercased()
        let requestsScreen = screenCaptureRequested(for: request)
        let isConversationRecall = DexterContextRelevancePlanner.matchesConversationRecallPublic(normalizedMessage)
        let isVisual = DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: request.userMessage)
            || requestsScreen
            || matchesPointerGuidanceIntent(normalizedMessage)
        let isErrorDebugging = DexterContextRelevancePlanner.matchesErrorDebuggingPublic(normalizedMessage)
        let isWorkflowMessage = matchesWorkflowContinuation(normalizedMessage)
        let isApplicationMessage = matchesApplicationIntent(normalizedMessage)

        if DexterPersonalContextIntentRecognizer.isPersonalContextQuery(request.userMessage) {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .project,
                collectPermissions: true,
                collectPointer: false,
                collectPointerTarget: false,
                collectActiveApplication: true,
                collectActiveWindow: true,
                collectSelectedText: false,
                collectScreenContext: false,
                collectClipboard: false,
                collectConversation: request.includeRecentConversation,
                collectRecentActions: true,
                collectCurrentTask: true,
                collectMemory: true,
                collectProjectContext: true,
                collectBrowserContext: true,
                collectAvailableTools: false
            )
        }

        if isConversationRecall && !isVisual && !isErrorDebugging {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .user,
                collectPermissions: false,
                collectPointer: false,
                collectPointerTarget: false,
                collectActiveApplication: false,
                collectActiveWindow: false,
                collectSelectedText: false,
                collectScreenContext: false,
                collectClipboard: false,
                collectConversation: request.includeRecentConversation,
                collectRecentActions: false,
                collectCurrentTask: false,
                collectMemory: true,
                collectProjectContext: false,
                collectBrowserContext: false,
                collectAvailableTools: false
            )
        }

        if isVisual {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .object,
                collectPermissions: true,
                collectPointer: true,
                collectPointerTarget: true,
                collectActiveApplication: true,
                collectActiveWindow: true,
                collectSelectedText: true,
                collectScreenContext: requestsScreen,
                collectClipboard: DexterClipboardContextEvaluator.shouldIncludeClipboard(forUserMessage: request.userMessage),
                collectConversation: request.includeRecentConversation,
                collectRecentActions: false,
                collectCurrentTask: false,
                collectMemory: true,
                collectProjectContext: false,
                collectBrowserContext: true,
                collectAvailableTools: false
            )
        }

        if isErrorDebugging {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .window,
                collectPermissions: true,
                collectPointer: true,
                collectPointerTarget: true,
                collectActiveApplication: true,
                collectActiveWindow: true,
                collectSelectedText: true,
                collectScreenContext: requestsScreen,
                collectClipboard: false,
                collectConversation: request.includeRecentConversation,
                collectRecentActions: true,
                collectCurrentTask: true,
                collectMemory: true,
                collectProjectContext: true,
                collectBrowserContext: true,
                collectAvailableTools: true
            )
        }

        if isWorkflowMessage {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .workflow,
                collectPermissions: true,
                collectPointer: false,
                collectPointerTarget: false,
                collectActiveApplication: true,
                collectActiveWindow: true,
                collectSelectedText: false,
                collectScreenContext: false,
                collectClipboard: false,
                collectConversation: request.includeRecentConversation,
                collectRecentActions: true,
                collectCurrentTask: true,
                collectMemory: true,
                collectProjectContext: true,
                collectBrowserContext: false,
                collectAvailableTools: true
            )
        }

        if isApplicationMessage {
            return DexterContextCollectionPlan(
                minimumRelevanceLevel: .application,
                collectPermissions: true,
                collectPointer: false,
                collectPointerTarget: false,
                collectActiveApplication: true,
                collectActiveWindow: false,
                collectSelectedText: false,
                collectScreenContext: false,
                collectClipboard: false,
                collectConversation: request.includeRecentConversation,
                collectRecentActions: true,
                collectCurrentTask: false,
                collectMemory: true,
                collectProjectContext: false,
                collectBrowserContext: false,
                collectAvailableTools: true
            )
        }

        return DexterContextCollectionPlan(
            minimumRelevanceLevel: .user,
            collectPermissions: false,
            collectPointer: false,
            collectPointerTarget: false,
            collectActiveApplication: false,
            collectActiveWindow: false,
            collectSelectedText: false,
            collectScreenContext: false,
            collectClipboard: false,
            collectConversation: request.includeRecentConversation,
            collectRecentActions: false,
            collectCurrentTask: false,
            collectMemory: true,
            collectProjectContext: false,
            collectBrowserContext: false,
            collectAvailableTools: false
        )
    }

    private static func screenCaptureRequested(for request: DexterContextAssemblyRequest) -> Bool {
        switch request.screenCaptureMode {
        case .skip:
            return false
        case .captureAllDisplaysIfPermitted, .captureCursorDisplayIfPermitted, .useOverride:
            return true
        }
    }

    private static func matchesWorkflowContinuation(_ normalizedMessage: String) -> Bool {
        let phrases = ["continue", "next step", "workflow", "assignment", "submit", "step "]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesApplicationIntent(_ normalizedMessage: String) -> Bool {
        let phrases = ["open ", "quit ", "focus ", "launch ", "close app", "switch to "]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func matchesPointerGuidanceIntent(_ normalizedMessage: String) -> Bool {
        DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedMessage)
            || normalizedMessage.contains("why is this red")
            || normalizedMessage.contains("why is that red")
    }
}
