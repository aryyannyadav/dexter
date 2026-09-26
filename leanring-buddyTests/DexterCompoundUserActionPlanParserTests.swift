//
//  DexterCompoundUserActionPlanParserTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterCompoundUserActionPlanParserTests {
    @Test func plansSettingsNavigationAfterCompoundLaunchPhrase() {
        let context = DexterContext(userMessage: DexterUserMessageContext(text: "open telegram and open settings there"))
        let followUpActions = DexterCompoundUserActionPlanParser.followUpActions(
            normalizedUserMessage: "open telegram and open settings there",
            context: context
        )
        #expect(followUpActions.count == 1)
        #expect(followUpActions[0].type == .keyboardShortcut)
        #expect(followUpActions[0].parameters["shortcut"] == "command ,")
    }

    @Test func plansUserInterfaceDestinationAfterGoToClause() {
        let context = DexterContext(userMessage: DexterUserMessageContext(text: "open telegram and go to calls section there"))
        let followUpActions = DexterCompoundUserActionPlanParser.followUpActions(
            normalizedUserMessage: "open telegram and go to calls section there",
            context: context,
            launchedApplicationName: "Telegram"
        )
        #expect(followUpActions.count == 1)
        #expect(followUpActions[0].type == .navigate)
        #expect(followUpActions[0].parameters["uiDestination"] == "Calls")
        #expect(followUpActions[0].parameters["parentApplicationName"] == "Telegram")
    }
}
