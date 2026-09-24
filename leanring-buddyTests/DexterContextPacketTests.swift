//
//  DexterContextPacketTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterContextPacketTests {
    @Test func collectionPlannerUsesObjectLevelForVisualRequests() {
        let plan = DexterContextCollectionPlanner.plan(
            for: DexterContextAssemblyRequest(
                userMessage: "What is this?",
                screenCaptureMode: .captureCursorDisplayIfPermitted
            )
        )
        #expect(plan.minimumRelevanceLevel == .object)
        #expect(plan.collectScreenContext)
        #expect(plan.collectPointerTarget)
        #expect(!plan.collectRecentActions)
    }

    @Test func collectionPlannerSkipsScreenForGreeting() {
        let plan = DexterContextCollectionPlanner.plan(
            for: DexterContextAssemblyRequest(
                userMessage: "hello",
                screenCaptureMode: .skip,
                includeRecentConversation: true
            )
        )
        #expect(plan.minimumRelevanceLevel == .user)
        #expect(!plan.collectScreenContext)
        #expect(!plan.collectPointer)
        #expect(!plan.collectActiveApplication)
        #expect(plan.collectConversation)
    }

    @Test func collectionPlannerIncludesWorkflowContextForContinue() {
        let plan = DexterContextCollectionPlanner.plan(
            for: DexterContextAssemblyRequest(
                userMessage: "continue the workflow",
                screenCaptureMode: .skip
            )
        )
        #expect(plan.minimumRelevanceLevel == .workflow)
        #expect(plan.collectCurrentTask)
        #expect(plan.collectRecentActions)
        #expect(plan.collectProjectContext)
    }

    @Test func collectionPlannerIncludesApplicationContextForOpenIntent() {
        let plan = DexterContextCollectionPlanner.plan(
            for: DexterContextAssemblyRequest(
                userMessage: "open SampleApp",
                screenCaptureMode: .skip
            )
        )
        #expect(plan.minimumRelevanceLevel == .application)
        #expect(plan.collectActiveApplication)
        #expect(plan.collectAvailableTools)
        #expect(!plan.collectScreenContext)
    }

    @Test func assemblerSkipsScreenAndPointerForNonVisualTurn() async {
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: true,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: true
                )
            ),
            memoryStore: DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 3),
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: DexterWorkflowTaskStateStore(
                memoryStore: DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 3)
            )
        )

        let result = await assembler.assembleContextPacket(
            request: DexterContextAssemblyRequest(
                userMessage: "hello",
                screenCaptureMode: .skip,
                includeRecentConversation: false
            )
        )

        #expect(result.packet.screenContext == nil)
        #expect(result.packet.pointer == nil)
        #expect(result.packet.userIntent.userMessage == "hello")
        #expect(result.diagnostics.skippedSections.contains(where: { $0.sectionName == "screenContext" }))
        #expect(result.diagnostics.collectedSections.contains(where: { $0.sectionName == "userIntent" }))
        #expect(result.legacyContext.userMessage.text == "hello")
    }

    @Test func assemblerCollectsPermissionsAndIntentForVisualTurnWithoutCaptureWhenSkipped() async {
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: false,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 3),
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: DexterWorkflowTaskStateStore(
                memoryStore: DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 3)
            )
        )

        let result = await assembler.assembleContextPacket(
            request: DexterContextAssemblyRequest(
                userMessage: "what is this?",
                screenCaptureMode: .skip,
                includeRecentConversation: false
            )
        )

        #expect(result.packet.userIntent.minimumRelevanceLevel == .object)
        #expect(result.packet.permissions != nil)
        #expect(result.diagnostics.collectedSections.contains(where: { $0.sectionName == "permissions" }))
        #expect(result.diagnostics.skippedSections.contains(where: { $0.sectionName == "screenContext" }))
    }

    @Test func legacyMapperPreservesConversationAndMemory() {
        let packet = DexterContextPacket(
            userIntent: DexterUserIntentContext(userMessage: "hi", minimumRelevanceLevel: .user),
            activeApplication: nil,
            activeWindow: nil,
            display: nil,
            pointer: nil,
            pointerTarget: nil,
            screenContext: nil,
            selectedText: nil,
            clipboard: nil,
            memory: DexterPersistentMemoryContext(
                retrievedMemories: [
                    DexterStructuredMemoryRecord.explicitPreference(content: "dark", title: "Theme")
                ],
                workflowContext: nil
            ),
            conversation: DexterConversationContext(
                recentExchanges: [
                    DexterConversationExchange(userTranscript: "hi", assistantResponse: "hello")
                ]
            ),
            currentTask: nil,
            recentActions: nil,
            availableTools: nil,
            permissions: nil,
            projectContext: nil,
            browserContext: nil,
            attention: nil
        )

        let legacy = DexterContextPacketLegacyMapper.legacyContext(from: packet)
        #expect(legacy.persistentMemory.userPreferences.count == 1)
        #expect(legacy.conversation.recentExchanges.count == 1)
    }
}
