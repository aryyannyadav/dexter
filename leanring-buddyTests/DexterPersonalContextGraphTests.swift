//
//  DexterPersonalContextGraphTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterPersonalContextGraphTests {
    @Test func builderLinksUserPreferenceAndProjectTask() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        memoryStore.saveUserPreference(title: "Editor", content: "Use VS Code", provenance: .intentionalPreference)
        memoryStore.setActiveTask(description: "Finish memory engine", provenance: .explicitUserRequest)

        let authorizedInput = DexterAuthorizedPersonalContextInput(
            activeApplicationName: "Visual Studio Code",
            activeApplicationBundleIdentifier: "com.microsoft.VSCode",
            activeWindowTitle: "MemoryStore.swift — Dexter",
            browserPageTitle: nil,
            browserPageURL: nil,
            currentTaskDescription: memoryStore.activeTaskDescription,
            workflowSummary: nil,
            recentConversationExchanges: [],
            recentActionSummaries: [],
            retrievedMemories: memoryStore.persistentMemoryContext(forQuery: "task", limit: 6).retrievedMemories,
            accountabilityTasks: [],
            selectedTextSnippet: nil
        )

        let graph = DexterPersonalContextGraphBuilder.build(
            memoryStore: memoryStore,
            authorizedInput: authorizedInput
        )

        #expect(graph.entities.contains { $0.kind == .user })
        #expect(graph.entities.contains { $0.kind == .application && $0.sourceIntegration == "vscode" })
        #expect(graph.relationships.contains { $0.relationship == .userToPreference })
        #expect(graph.relationships.contains { $0.relationship == .projectToTask || $0.relationship == .owns })
    }

    @Test func catchMeUpUsesAuthorizedContextOnly() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        memoryStore.setActiveTask(description: "Write tests", provenance: .explicitUserRequest)

        let authorizedInput = DexterAuthorizedPersonalContextInput.memoryOnly(
            memoryStore: memoryStore,
            userMessage: "catch me up"
        )
        let graph = DexterPersonalContextGraphBuilder.build(
            memoryStore: memoryStore,
            authorizedInput: authorizedInput
        )
        let response = DexterPersonalContextQueryEngine.respond(
            queryKind: .catchMeUp,
            graph: graph,
            authorizedInput: authorizedInput
        )

        #expect(response.contains("Task: Write tests"))
        #expect(response.contains("authorized"))
    }

    @Test func intentRecognizerDetectsContinuePhrase() {
        #expect(
            DexterPersonalContextIntentRecognizer.recognize(fromUserMessage: "continue where we left off")
                == .continueWhereLeftOff
        )
    }

    @Test func browserIntegrationAddsApplicationEntity() {
        let authorizedInput = DexterAuthorizedPersonalContextInput(
            activeApplicationName: "Safari",
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeWindowTitle: "Dexter — Docs",
            browserPageTitle: "Dexter Docs",
            browserPageURL: "https://example.com/docs",
            currentTaskDescription: nil,
            workflowSummary: "Assignment workflow",
            recentConversationExchanges: [],
            recentActionSummaries: [],
            retrievedMemories: [],
            accountabilityTasks: [],
            selectedTextSnippet: nil
        )

        let integration = DexterPersonalContextIntegrations.browserIntegration(
            authorizedInput: authorizedInput,
            workflowEntityIdentifier: "workflow:active"
        )

        #expect(integration?.entities.first?.kind == .application)
        #expect(integration?.relationships.contains { $0.relationship == .workflowToApplication } == true)
    }
}
