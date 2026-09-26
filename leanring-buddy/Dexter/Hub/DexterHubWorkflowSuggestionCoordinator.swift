//
//  DexterHubWorkflowSuggestionCoordinator.swift
//
//  Surfaces a single lightweight workflow suggestion on Hub when session action history repeats.
//

import Foundation

@MainActor
final class DexterHubWorkflowSuggestionCoordinator {
    private weak var eventBridge: DexterHubEventBridge?
    private var actionHistoryProvider: (() -> DexterActionHistoryStore?)?
    private var didOfferSuggestionThisSession = false
    private var dismissedSuggestion = false
    private var acceptedRoutineIdentifier: String?

    func install(
        eventBridge: DexterHubEventBridge,
        actionHistoryProvider: @escaping () -> DexterActionHistoryStore?
    ) {
        self.eventBridge = eventBridge
        self.actionHistoryProvider = actionHistoryProvider
    }

    func evaluateAfterVerifiedCompletionIfIdle(isAmbientFocusMode: Bool) {
        guard !isAmbientFocusMode else { return }
        guard !didOfferSuggestionThisSession else { return }
        guard !dismissedSuggestion else { return }
        guard let actionHistoryStore = actionHistoryProvider?() else { return }

        let recentActions = actionHistoryStore.recentActions(limit: DexterHubRepeatedWorkPatternAnalyzer.recentActionWindow)
        guard let suggestion = DexterHubRepeatedWorkPatternAnalyzer.detectSuggestion(from: recentActions) else {
            return
        }

        didOfferSuggestionThisSession = true
        eventBridge?.broadcastWorkflowSuggestion(
            routineDisplayName: suggestion.routineDisplayName,
            patternSummary: suggestion.patternSummary,
            trustPreview: suggestion.trustPreview,
            routineRunSupported: suggestion.routineRunSupported,
            catalogWorkflowIdentifier: suggestion.catalogWorkflowIdentifier
        )
    }

    func handleHubResponse(_ response: String, catalogWorkflowIdentifier: String?) {
        switch response {
        case "yes":
            acceptedRoutineIdentifier = catalogWorkflowIdentifier
            eventBridge?.broadcastWorkflowRoutinePreview(
                routineDisplayName: catalogWorkflowIdentifier ?? "Your routine",
                trustPreview: "Dexter will ask before each step on your Mac. Nothing runs automatically from the tablet."
            )
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
        case "run":
            guard let catalogWorkflowIdentifier,
                  DexterWorkflowCatalog.workflow(forIdentifier: catalogWorkflowIdentifier) != nil
            else {
                return
            }
            NotificationCenter.default.post(
                name: DexterHubWorkflowSuggestionNotifications.dexterHubStartCatalogWorkflowRequested,
                object: nil,
                userInfo: [DexterHubWorkflowSuggestionNotifications.catalogWorkflowIdentifierUserInfoKey: catalogWorkflowIdentifier]
            )
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
        case "notNow":
            dismissedSuggestion = true
            eventBridge?.broadcastWorkflowSuggestionDismissed()
        default:
            break
        }
    }
}

enum DexterHubWorkflowSuggestionNotifications {
    static let catalogWorkflowIdentifierUserInfoKey = "catalogWorkflowIdentifier"
    static let dexterHubStartCatalogWorkflowRequested = Notification.Name("dexterHubStartCatalogWorkflowRequested")
}
