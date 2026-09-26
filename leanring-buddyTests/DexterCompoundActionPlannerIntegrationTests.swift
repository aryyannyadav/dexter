//
//  DexterCompoundActionPlannerIntegrationTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterCompoundActionPlannerIntegrationTests {
    @Test func compoundLaunchAndSettingsProducesActionSequence() {
        let outcome = DexterActionPlanner.planAction(
            forUserMessage: "open telegram and open settings there",
            responseMode: .act,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "open telegram and open settings there")),
            demonstrationSessionStore: DexterDemonstrationSessionStore()
        )

        guard case .actionSequence(let actions) = outcome else {
            Issue.record("Expected compound action sequence.")
            return
        }

        #expect(actions.count == 2)
        #expect(actions[0].type == .openApplication)
        #expect(actions[0].parameters["applicationName"] == "Telegram")
        #expect(actions[1].type == .keyboardShortcut)
    }
}
