//
//  DexterIntegrationProviderTests.swift
//  leanring-buddyTests
//

import Testing
@testable import leanring_buddy

struct DexterIntegrationProviderTests {
    @Test func visualStudioCodeParserExtractsFileAndWorkspace() {
        let parsed = DexterVisualStudioCodeWindowParser.parse(
            windowTitle: "MemoryStore.swift — Dexter — Visual Studio Code"
        )
        #expect(parsed.fileName == "MemoryStore.swift")
        #expect(parsed.workspaceName == "Dexter")
    }

    @Test func gitHubProviderActivatesOnGitHubURL() {
        let authorizedInput = DexterAuthorizedPersonalContextInput(
            activeApplicationName: "Safari",
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeWindowTitle: "Pull Request",
            browserPageTitle: "Fix memory engine",
            browserPageURL: "https://github.com/org/repo/pull/1",
            currentTaskDescription: "Ship context engine",
            workflowSummary: nil,
            recentConversationExchanges: [],
            recentActionSummaries: ["Open Calculator."],
            retrievedMemories: [],
            accountabilityTasks: [],
            selectedTextSnippet: nil
        )

        let graph = DexterPersonalContextGraphBuilder.build(
            memoryStore: DefaultMemoryStore.inMemoryForTesting(),
            authorizedInput: authorizedInput
        )

        #expect(graph.authorizedSourceLabels.contains("github"))
        #expect(graph.entities.contains { $0.id == "github:page" })

        let response = DexterPersonalContextQueryEngine.respond(
            queryKind: .whereWasI,
            graph: graph,
            authorizedInput: authorizedInput
        )
        #expect(response.contains("authorized"))
        #expect(response.contains("Current task memory") || response.contains("Ship context engine"))
    }
}
