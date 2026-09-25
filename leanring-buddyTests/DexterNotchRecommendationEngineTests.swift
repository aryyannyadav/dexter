//
//  DexterNotchRecommendationEngineTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterNotchRecommendationEngineTests {
    private static let defaultCapabilityReport = DexterOpenClawCapabilityDiscovery.report(
        gatewayConnected: true,
        nodeSnapshot: .unavailable
    )

    @Test func permissionOutranksWorkSuggestion() {
        let persistence = DexterSuggestionPersistenceStore()
        let profileId = UUID()
        let confirmation = DexterActionConfirmationPresentation(
            actionId: UUID(),
            riskLevel: .lowRisk,
            content: DexterActionConfirmationContent(
                whatWillHappen: "Open Safari",
                whyDexterWantsToDoIt: "You asked to browse",
                whereItWillHappen: "Safari",
                recoveryWarning: nil
            )
        )
        let workSuggestion = DexterProfileWorkSuggestion(
            id: "continue_builder",
            dexterProfileId: profileId,
            category: .continueWork,
            sectionTitle: "BUILDER",
            headline: "Continue building Dexter?",
            body: "Pick up the workspace task.",
            primaryActionTitle: "Continue",
            source: DexterProfileWorkSuggestionSource(
                kind: .unfinishedDexterTask,
                referenceIdentifier: "task",
                displayDetail: "Builder"
            ),
            action: .runAgent(userMessage: "Continue"),
            priority: 90,
            refreshedAt: Date(),
            isUnread: true
        )

        let input = DexterNotchRecommendationEngine.Input(
            runtimeState: .waitingPermission,
            runtimeDetail: "Waiting for approval",
            failurePresentation: nil,
            voiceInteractionState: .idle,
            actionConfirmation: confirmation,
            activeProfileName: "Builder",
            activeProfileId: profileId,
            profileWorkSuggestions: [workSuggestion],
            openAccountabilityTasks: [],
            integrations: [],
            capabilityDiscoveryReport: Self.defaultCapabilityReport,
            openClawGatewayConnected: true,
            lastUserMessageText: nil,
            agentCompletionSnapshot: nil,
            lastFailedActionId: nil,
            lastFailedActionDescription: nil,
            userFirstName: "Aryan",
            evaluatedAt: Date()
        )

        let resolved = DexterNotchRecommendationEngine.resolve(input: input, persistence: persistence)
        #expect(resolved?.kind == .permissionRequest)
    }

    @Test func busyAgentSuppressesMediumSuggestions() {
        let persistence = DexterSuggestionPersistenceStore()
        let profileId = UUID()
        let workSuggestion = DexterProfileWorkSuggestion(
            id: "continue_builder",
            dexterProfileId: profileId,
            category: .continueWork,
            sectionTitle: "BUILDER",
            headline: "Continue building Dexter?",
            body: "Pick up the workspace task.",
            primaryActionTitle: "Continue",
            source: DexterProfileWorkSuggestionSource(
                kind: .unfinishedDexterTask,
                referenceIdentifier: "task",
                displayDetail: "Builder"
            ),
            action: .runAgent(userMessage: "Continue"),
            priority: 90,
            refreshedAt: Date(),
            isUnread: true
        )

        let input = DexterNotchRecommendationEngine.Input(
            runtimeState: .acting,
            runtimeDetail: "Clicking button",
            failurePresentation: nil,
            voiceInteractionState: .idle,
            actionConfirmation: nil,
            activeProfileName: "Builder",
            activeProfileId: profileId,
            profileWorkSuggestions: [workSuggestion],
            openAccountabilityTasks: [],
            integrations: [],
            capabilityDiscoveryReport: Self.defaultCapabilityReport,
            openClawGatewayConnected: true,
            lastUserMessageText: nil,
            agentCompletionSnapshot: nil,
            lastFailedActionId: nil,
            lastFailedActionDescription: nil,
            userFirstName: "Aryan",
            evaluatedAt: Date()
        )

        let resolved = DexterNotchRecommendationEngine.resolve(input: input, persistence: persistence)
        #expect(resolved?.kind == .activeDexter)
    }

    @Test func dismissedIntegrationPromptIsNotRepeated() {
        let persistence = DexterSuggestionPersistenceStore()
        let persistenceId = "capability_connect:github"
        persistence.markDismissed(identifier: persistenceId)

        let input = DexterNotchRecommendationEngine.Input(
            runtimeState: .idle,
            runtimeDetail: "",
            failurePresentation: nil,
            voiceInteractionState: .idle,
            actionConfirmation: nil,
            activeProfileName: "Builder",
            activeProfileId: UUID(),
            profileWorkSuggestions: [],
            openAccountabilityTasks: [],
            integrations: [
                DexterIntegration(
                    id: "github",
                    name: "GitHub",
                    kind: .operational,
                    connectionState: .notConnected
                )
            ],
            capabilityDiscoveryReport: Self.defaultCapabilityReport,
            openClawGatewayConnected: true,
            lastUserMessageText: "Check my GitHub issues",
            agentCompletionSnapshot: nil,
            lastFailedActionId: nil,
            lastFailedActionDescription: nil,
            userFirstName: "Aryan",
            evaluatedAt: Date()
        )

        let resolved = DexterNotchRecommendationEngine.resolve(input: input, persistence: persistence)
        #expect(resolved?.kind != .integrationRecommendation)
    }
}
