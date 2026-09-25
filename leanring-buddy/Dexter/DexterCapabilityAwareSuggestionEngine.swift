//
//  DexterCapabilityAwareSuggestionEngine.swift
//  leanring-buddy
//

import Foundation

/// Intent → required capability → compare registry / integrations → connect suggestion when missing.
enum DexterCapabilityAwareSuggestionEngine {
    struct EvaluationInput: Equatable {
        let userMessageText: String
        let integrations: [DexterIntegration]
        let capabilityDiscoveryReport: DexterOpenClawCapabilityDiscoveryReport
        let gatewayConnected: Bool
    }

    static func connectSuggestion(from input: EvaluationInput) -> DexterCapabilityAwareSuggestion? {
        let normalizedMessage = input.userMessageText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedMessage.isEmpty else { return nil }

        let requirements = requiredCapabilities(from: normalizedMessage)
        guard !requirements.isEmpty else { return nil }

        for requirement in requirements {
            if isRequirementSatisfied(requirement, input: input) {
                continue
            }
            return suggestion(for: requirement)
        }
        return nil
    }

    static func requiredCapabilities(from normalizedMessage: String) -> [DexterCapabilityRequirement] {
        var requirements: [DexterCapabilityRequirement] = []

        if let integrationRequirement = integrationRequirement(from: normalizedMessage) {
            requirements.append(integrationRequirement)
        }

        if computerControlRequirement(from: normalizedMessage) != nil {
            requirements.append(
                DexterCapabilityRequirement(
                    kind: .openClawComputerControl,
                    intentSummary: "computer_action"
                )
            )
        }

        return requirements
    }

    static func isRequirementSatisfied(
        _ requirement: DexterCapabilityRequirement,
        input: EvaluationInput
    ) -> Bool {
        switch requirement.kind {
        case .integrationConnect(let integrationId, _):
            guard let integration = input.integrations.first(where: { $0.id == integrationId }) else {
                return false
            }
            return integration.connectionState == .connected
        case .openClawComputerControl:
            return input.capabilityDiscoveryReport.isCapabilityAvailable(.computerAct)
                && input.gatewayConnected
                && input.capabilityDiscoveryReport.nodeConnected
        }
    }

    private static func suggestion(for requirement: DexterCapabilityRequirement) -> DexterCapabilityAwareSuggestion {
        switch requirement.kind {
        case .integrationConnect(let integrationId, let displayName):
            return DexterCapabilityAwareSuggestion(
                requirement: requirement,
                headline: "Connect \(displayName)",
                body: "Dexter needs \(displayName) to handle that request.",
                primaryActionTitle: "Connect",
                integrationIdForSettings: integrationId
            )
        case .openClawComputerControl:
            return DexterCapabilityAwareSuggestion(
                requirement: requirement,
                headline: "Connect OpenClaw",
                body: "Computer control isn't available yet. Connect OpenClaw to run actions like opening apps.",
                primaryActionTitle: "Connect",
                integrationIdForSettings: "openclaw-gateway"
            )
        }
    }

    // MARK: - Intent → requirement

    private struct IntegrationIntentRule: Equatable {
        let keywords: [String]
        let displayName: String
    }

    private static let integrationIntentRules: [IntegrationIntentRule] = [
        IntegrationIntentRule(keywords: ["github", "pull request", "pull requests", "my issues", "github issues"], displayName: "GitHub"),
        IntegrationIntentRule(keywords: ["notion"], displayName: "Notion"),
        IntegrationIntentRule(keywords: ["google calendar", "gcal", "calendar event"], displayName: "Google Calendar"),
        IntegrationIntentRule(keywords: ["google docs", "gdoc"], displayName: "Google Docs"),
        IntegrationIntentRule(keywords: ["slack"], displayName: "Slack"),
        IntegrationIntentRule(keywords: ["linear"], displayName: "Linear"),
        IntegrationIntentRule(keywords: ["jira"], displayName: "Jira")
    ]

    private static func integrationRequirement(from normalizedMessage: String) -> DexterCapabilityRequirement? {
        for rule in integrationIntentRules {
            guard rule.keywords.contains(where: { normalizedMessage.contains($0) }) else { continue }
            let integrationId = integrationIdentifier(forDisplayName: rule.displayName)
            return DexterCapabilityRequirement(
                kind: .integrationConnect(integrationId: integrationId, displayName: rule.displayName),
                intentSummary: "integration:\(rule.displayName)"
            )
        }
        return nil
    }

    static func integrationIdentifier(forDisplayName displayName: String) -> String {
        switch displayName.lowercased() {
        case "github":
            return "github"
        default:
            let slug = displayName.lowercased().replacingOccurrences(of: " ", with: "-")
            return "discovery-\(slug)"
        }
    }

    private static let computerControlPhrases = [
        "open ", "launch ", "start ", "quit ", "close ", "focus ",
        "click ", "press ", "scroll ", "type "
    ]

    private static func computerControlRequirement(from normalizedMessage: String) -> DexterCapabilityRequirement? {
        if integrationIntentRules.contains(where: { rule in
            rule.keywords.contains(where: { normalizedMessage.contains($0) })
        }) {
            return nil
        }

        let matchesComputerVerb = computerControlPhrases.contains { normalizedMessage.contains($0) }
        guard matchesComputerVerb else { return nil }

        return DexterCapabilityRequirement(
            kind: .openClawComputerControl,
            intentSummary: "computer_action"
        )
    }
}
