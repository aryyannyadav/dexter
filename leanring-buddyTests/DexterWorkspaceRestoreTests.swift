//
//  DexterWorkspaceRestoreTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterWorkspaceRestoreTests {
    @Test func intentRecognizerDetectsSaveAndRestore() {
        #expect(DexterWorkspaceIntentRecognizer.recognizeSave(fromUserMessage: "please save my workspace"))
        #expect(DexterWorkspaceIntentRecognizer.recognizeRestore(fromUserMessage: "restore my workspace now"))
        #expect(!DexterWorkspaceIntentRecognizer.recognizeRestore(fromUserMessage: "what am I working on"))
    }

    @Test func captureBuildsSemanticSnapshotWithoutCoordinates() {
        let authorizedInput = DexterAuthorizedPersonalContextInput(
            activeApplicationName: "Safari",
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeWindowTitle: "Dexter Docs",
            browserPageTitle: "Dexter Docs",
            browserPageURL: "https://example.com/docs",
            currentTaskDescription: "Finish workspace restore",
            workflowSummary: nil,
            recentConversationExchanges: [],
            recentActionSummaries: [],
            retrievedMemories: [],
            accountabilityTasks: [],
            selectedTextSnippet: nil
        )

        let graph = DexterPersonalContextGraphBuilder.build(
            memoryStore: DefaultMemoryStore.inMemoryForTesting(),
            authorizedInput: authorizedInput
        )

        let snapshot = DexterWorkspaceSnapshotCapture.capture(
            authorizedInput: authorizedInput,
            personalContextGraph: graph,
            accountabilitySnapshot: .empty
        )

        #expect(snapshot.frontmostApplication?.displayName == "Safari")
        #expect(snapshot.browserTab?.pageURL == "https://example.com/docs")
        #expect(snapshot.activeTaskDescription == "Finish workspace restore")
        #expect(snapshot.foregroundWindow?.windowTitle == "Dexter Docs")
    }

    @Test func plannerOpensApplicationWhenFrontmostDiffers() {
        let desiredSnapshot = DexterWorkspaceSnapshot(
            frontmostApplication: DexterWorkspaceApplicationReference(
                displayName: "Visual Studio Code",
                bundleIdentifier: "com.microsoft.VSCode"
            )
        )

        let currentState = DexterWorkspaceCurrentState(
            authorizedInput: DexterAuthorizedPersonalContextInput(
                activeApplicationName: "Safari",
                activeApplicationBundleIdentifier: "com.apple.Safari",
                activeWindowTitle: nil,
                browserPageTitle: nil,
                browserPageURL: nil,
                currentTaskDescription: nil,
                workflowSummary: nil,
                recentConversationExchanges: [],
                recentActionSummaries: [],
                retrievedMemories: [],
                accountabilityTasks: [],
                selectedTextSnippet: nil
            ),
            personalContextGraph: DexterPersonalContextGraphSnapshot(
                entities: [],
                relationships: [],
                authorizedSourceLabels: []
            ),
            accountabilitySnapshot: .empty
        )

        let comparison = DexterWorkspaceRestorePlanner.compare(
            desiredSnapshot: desiredSnapshot,
            currentState: currentState
        )
        let steps = DexterWorkspaceRestorePlanner.planSteps(
            desiredSnapshot: desiredSnapshot,
            comparison: comparison
        )

        #expect(comparison.gaps.contains { $0.category == "application" })
        #expect(steps.contains { $0.kind == .openApplication })
        #expect(steps.allSatisfy { $0.proposedAction?.type != .click })
    }

    @Test func plannerSkipsWhenBrowserURLAlreadyMatches() {
        let desiredSnapshot = DexterWorkspaceSnapshot(
            browserTab: DexterWorkspaceBrowserTabReference(
                browserApplicationName: "Safari",
                pageTitle: "Docs",
                pageURL: "https://example.com/docs"
            )
        )

        let currentState = DexterWorkspaceCurrentState(
            authorizedInput: DexterAuthorizedPersonalContextInput(
                activeApplicationName: "Safari",
                activeApplicationBundleIdentifier: "com.apple.Safari",
                activeWindowTitle: nil,
                browserPageTitle: "Docs",
                browserPageURL: "https://example.com/docs/",
                currentTaskDescription: nil,
                workflowSummary: nil,
                recentConversationExchanges: [],
                recentActionSummaries: [],
                retrievedMemories: [],
                accountabilityTasks: [],
                selectedTextSnippet: nil
            ),
            personalContextGraph: DexterPersonalContextGraphSnapshot(
                entities: [],
                relationships: [],
                authorizedSourceLabels: []
            ),
            accountabilitySnapshot: .empty
        )

        let comparison = DexterWorkspaceRestorePlanner.compare(
            desiredSnapshot: desiredSnapshot,
            currentState: currentState
        )
        let steps = DexterWorkspaceRestorePlanner.planSteps(
            desiredSnapshot: desiredSnapshot,
            comparison: comparison
        )

        #expect(comparison.gaps.isEmpty)
        #expect(steps.isEmpty)
    }

    @Test func snapshotStoreKeepsLatestSnapshot() {
        let store = DexterWorkspaceSnapshotStore(storageURL: nil)
        let firstSnapshot = DexterWorkspaceSnapshot(label: "first")
        let secondSnapshot = DexterWorkspaceSnapshot(label: "second")
        store.save(firstSnapshot)
        store.save(secondSnapshot)

        #expect(store.latestSnapshot()?.label == "second")
        #expect(store.allSnapshots().count == 2)
    }
}
