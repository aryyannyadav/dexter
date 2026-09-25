//
//  DexterSuggestionCapabilityFilter.swift
//  leanring-buddy
//

import Foundation

enum DexterSuggestionCapabilityFilter {
    static func requiredCapability(for suggestion: DexterSuggestion) -> DexterProductCapabilityID? {
        switch suggestion.kind {
        case .explainError:
            return .screenUnderstanding
        case .summarizePage:
            return .browserNavigation
        case .organizeFiles:
            return suggestion.outcome == .action ? .filesLocal : .researchConversation
        case .finishTask, .continueWhereLeftOff:
            return .researchConversation
        }
    }

    static func filterSuggestions(
        _ suggestions: [DexterSuggestion],
        capabilities: [DexterProductCapability],
        integrations: [DexterIntegration]
    ) -> [DexterSuggestion] {
        suggestions.filter { suggestion in
            guard let required = requiredCapability(for: suggestion) else { return true }
            return DexterProductCapabilityRegistry.isCapabilityUsable(required, in: capabilities)
        }
    }

    static func connectAlternativeSuggestion(
        for blockedUserMessage: String,
        integrations: [DexterIntegration],
        capabilityDiscoveryReport: DexterOpenClawCapabilityDiscoveryReport,
        gatewayConnected: Bool
    ) -> DexterCapabilityAwareSuggestion? {
        let evaluation = DexterCapabilityAwareSuggestionEngine.EvaluationInput(
            userMessageText: blockedUserMessage,
            integrations: integrations,
            capabilityDiscoveryReport: capabilityDiscoveryReport,
            gatewayConnected: gatewayConnected
        )
        return DexterCapabilityAwareSuggestionEngine.connectSuggestion(from: evaluation)
    }
}
