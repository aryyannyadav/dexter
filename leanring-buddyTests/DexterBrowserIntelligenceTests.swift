//
//  DexterBrowserIntelligenceTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterBrowserIntelligenceTests {
    @Test func plannerOpenYouTube() {
        let outcome = DexterBrowserIntelligencePlanner.planAction(
            normalizedUserMessage: "open youtube",
            context: browserContext()
        )
        guard case .action(let action) = outcome else {
            Issue.record("Expected browser open action.")
            return
        }
        #expect(action.parameters["browserAction"] == "open")
        #expect(action.parameters["url"]?.contains("youtube.com") == true)
    }

    @Test func plannerSearchForQuery() {
        let outcome = DexterBrowserIntelligencePlanner.planAction(
            normalizedUserMessage: "search for swift concurrency",
            context: browserContext()
        )
        guard case .action(let action) = outcome else {
            Issue.record("Expected browser search action.")
            return
        }
        #expect(action.parameters["browserAction"] == "search")
        #expect(action.parameters["query"] == "swift concurrency")
    }

    @Test func toolMapsBrowserSearchProposal() {
        let proposal = DexterRegisteredToolProposal(
            toolName: DexterRegisteredToolName.browserSearch.rawValue,
            parameters: ["query": "documentation"]
        )
        let invocation = DexterRegisteredToolRouter.toolInvocation(for: proposal)
        #expect(invocation?.registeredToolName == DexterRegisteredToolName.browserSearch.rawValue)
        #expect(invocation?.parameters["browserAction"] == "search")
    }

    @Test func verificationFailsWithoutBrowserEvidence() {
        let action = DexterActionFactory.browserOpen(url: "https://www.youtube.com", verificationHint: "youtube")
        let report = DexterBrowserVerificationEngine.verify(
            action: action,
            observationAfter: DexterActionObservationSnapshot.empty,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "task-1",
                rawOutput: nil
            )
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("won't claim"))
    }

    @Test func verificationSucceedsWithRuntimeURL() {
        let action = DexterActionFactory.browserOpen(url: "https://www.youtube.com", verificationHint: "youtube")
        let report = DexterBrowserVerificationEngine.verify(
            action: action,
            observationAfter: DexterActionObservationSnapshot.empty,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "task-1",
                rawOutput: #"{"url":"https://www.youtube.com","title":"YouTube"}"#
            )
        )
        #expect(report.status == .verified)
    }

    @Test func catalogIncludesAllBrowserTools() {
        let browserTools: Set<DexterRegisteredToolName> = [
            .browserOpen,
            .browserNavigate,
            .browserSearch,
            .browserRead,
            .browserClick,
            .browserType,
            .browserBack,
            .browserForward
        ]
        let catalogNames = Set(DexterToolRegistryCatalog.allDefinitions.map(\.name))
        #expect(browserTools.isSubset(of: catalogNames))
    }

    private static func browserContext() -> DexterContext {
        DexterContext(
            userMessage: DexterUserMessageContext(text: "open youtube"),
            activeApplication: DexterActiveApplicationContext(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari",
                availability: .available
            ),
            activeWindow: DexterActiveWindowContext(title: "Start Page", availability: .available)
        )
    }
}
