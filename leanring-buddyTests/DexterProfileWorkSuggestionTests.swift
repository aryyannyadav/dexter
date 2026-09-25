//
//  DexterProfileWorkSuggestionTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterProfileWorkSuggestionTests {
    @Test func engineRequiresSourceForContinueConversation() {
        let profiles = DexterProfileSeedFactory.seedProfiles()
        let studyId = DexterSeedProfileIdentifier.studyBuddy
        let recents = [
            DexterRecentConversationSummary(
                id: UUID(),
                title: "C++ constructors",
                lastUpdated: Date(),
                dexterProfileId: studyId
            )
        ]

        let persistence = DexterSuggestionPersistenceStore()
        let input = DexterProfileWorkSuggestionEngineInput(
            profiles: profiles,
            recentConversations: recents,
            persistentMemorySummaries: [],
            activeWorkflowTaskTitle: nil,
            activeTaskDescription: nil,
            accountabilityTasks: [],
            lastFailedAction: nil,
            openClawGatewayConnected: true,
            engineSuggestions: [],
            lastUserMessageText: nil,
            integrations: [],
            capabilityDiscoveryReport: DexterOpenClawCapabilityDiscovery.report(
                gatewayConnected: true,
                nodeSnapshot: .unavailable
            ),
            evaluatedAt: Date()
        )

        let generated = DexterProfileWorkSuggestionEngine.generateSuggestions(
            input: input,
            persistence: persistence
        )

        let studySuggestions = generated[studyId] ?? []
        #expect(studySuggestions.count == 1)
        #expect(studySuggestions[0].source.kind == .conversation)
        #expect(studySuggestions[0].action == .openConversation(conversationId: recents[0].id))
        #expect(studySuggestions[0].body.contains("C++ constructors"))
    }

    @Test func dismissPersistenceBlocksRepeatOffer() {
        let persistence = DexterSuggestionPersistenceStore()
        let identifier = "profile_work:test:dismiss"
        persistence.markDismissed(identifier: identifier)
        #expect(!persistence.shouldOfferSuggestion(identifier: identifier, now: Date()))
    }

    @Test func dashboardLimitsSuggestionCount() {
        let profileA = DexterProfileSeedFactory.seedProfiles()[0]
        let profileB = DexterProfileSeedFactory.seedProfiles()[1]
        let suggestionA = makeSuggestion(profileId: profileA.id, priority: 50, id: "a")
        let suggestionB = makeSuggestion(profileId: profileB.id, priority: 100, id: "b")
        let suggestionC = makeSuggestion(profileId: profileB.id, priority: 90, id: "c")

        let highlights = DexterProfileWorkSuggestionEngine.homeDashboardSuggestions(from: [
            profileA.id: [suggestionA],
            profileB.id: [suggestionB, suggestionC]
        ])

        #expect(highlights.count == 3)
        #expect(highlights.first?.id == "b")
    }

    private func makeSuggestion(profileId: UUID, priority: Int, id: String) -> DexterProfileWorkSuggestion {
        DexterProfileWorkSuggestion(
            id: id,
            dexterProfileId: profileId,
            category: .continueWork,
            sectionTitle: "CONTINUE WORK",
            headline: "Test",
            body: "Body",
            primaryActionTitle: "Go",
            source: DexterProfileWorkSuggestionSource(
                kind: .conversation,
                referenceIdentifier: "ref",
                displayDetail: "detail"
            ),
            action: .runAgent(userMessage: "Help"),
            priority: priority,
            refreshedAt: Date(),
            isUnread: true
        )
    }
}
