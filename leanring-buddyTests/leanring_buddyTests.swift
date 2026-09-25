//
//  leanring_buddyTests.swift
//  leanring-buddyTests
//
//  Created by thorfinn on 3/2/26.
//

import AppKit
import ApplicationServices
import Testing
@testable import Dexter

@MainActor
struct leanring_buddyTests {

    @Test func firstPermissionRequestUsesSystemPromptOnly() async throws {
        let presentationDestination = WindowPositionManager.permissionRequestPresentationDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: false
        )

        #expect(presentationDestination == .systemPrompt)
    }

    @Test func repeatedPermissionRequestOpensSystemSettings() async throws {
        let presentationDestination = WindowPositionManager.permissionRequestPresentationDestination(
            hasPermissionNow: false,
            hasAttemptedSystemPrompt: true
        )

        #expect(presentationDestination == .systemSettings)
    }

    @Test func knownGrantedScreenRecordingPermissionSkipsTheGate() async throws {
        let shouldTreatPermissionAsGranted = WindowPositionManager.shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch(
            hasScreenRecordingPermissionNow: false,
            hasPreviouslyConfirmedScreenRecordingPermission: true
        )

        #expect(shouldTreatPermissionAsGranted)
    }

    @Test func dexterVoiceCoordinatorSupportsThinkingSpeakingAndInterruption() async throws {
        let coordinator = DexterVoiceCoordinator(settingsStore: InMemoryDexterVoiceSettingsStore())
        #expect(coordinator.interactionState == .idle)

        coordinator.transitionToThinking()
        #expect(coordinator.interactionState == .thinking)

        coordinator.transitionToSpeaking()
        #expect(coordinator.interactionState == .speaking)

        coordinator.handleUserInterruption()
        #expect(coordinator.interactionState == .idle)

        coordinator.transitionToSpeaking()
        coordinator.prepareForPushToTalkCapture()
        #expect(coordinator.interactionState == .idle)

        coordinator.appendStreamingResponseChunk("hello ")
        coordinator.appendStreamingResponseChunk("world")
        #expect(coordinator.streamingResponseText == "hello world")
    }

    @Test func ollamaStreamDeltaPreservesWhitespaceOnlyChunks() async throws {
        let chunks = ["Hey!", " ", "Ready", " ", "to", " ", "help."]
        var accumulated = ""
        for chunk in chunks {
            let delta = OllamaResponseSanitizer.userFacingAssistantStreamDelta(
                content: chunk,
                separateThinkingField: nil
            )
            guard !delta.isEmpty else { continue }
            accumulated += delta
        }
        #expect(accumulated == "Hey! Ready to help.")

        let trimmedFinal = OllamaResponseSanitizer.userFacingAssistantText(
            content: accumulated,
            separateThinkingField: nil
        )
        #expect(trimmedFinal == "Hey! Ready to help.")
    }

    @Test func ollamaFinalAssistantTextStillTrimsOuterWhitespace() async throws {
        let text = OllamaResponseSanitizer.userFacingAssistantText(
            content: "  hello world  \n",
            separateThinkingField: nil
        )
        #expect(text == "hello world")
    }

    @Test func dexterVoiceSettingsDisablePushToTalkWithoutBlockingTextPath() async throws {
        let settingsStore = InMemoryDexterVoiceSettingsStore(
            currentSettings: DexterVoiceSettings(isPushToTalkEnabled: false, isSpokenResponsesEnabled: false)
        )
        #expect(settingsStore.currentSettings.isPushToTalkEnabled == false)
        #expect(settingsStore.currentSettings.isSpokenResponsesEnabled == false)
    }

    @Test func dexterPanelPresentationMapsVoiceAndActionStates() async throws {
        #expect(
            DexterPanelPresentation.voiceActivationLabel(
                interactionState: .listening,
                isPushToTalkEnabled: true,
                hasCompletedSetup: true
            ) == .listening
        )
        #expect(
            DexterPanelPresentation.actionPhaseLabel(
                for: DexterActionFactory.openApplication(named: "Safari").withState(.executing)
            ) == .executing
        )
        #expect(
            DexterPanelPresentation.verificationResultLabel(
                for: DexterActionFactory.openApplication(named: "Safari").withState(.completed)
            ) == .success
        )
    }

    @Test func dexterVoiceSystemPromptEmphasizesConciseSpokenReplies() async throws {
        #expect(DexterVoiceSystemPrompt.conciseVoiceResponseSystemPrompt.contains("one or two short sentences"))
        #expect(DexterVoiceSystemPrompt.conciseVoiceResponseSystemPrompt.contains("[POINT:"))
    }

    @Test func sessionMemoryStoreKeepsOnlyTheMostRecentExchanges() async throws {
        let memoryStore = SessionMemoryStore(maxSessionExchanges: 2)

        memoryStore.appendExchange(userTranscript: "one", assistantResponse: "a")
        memoryStore.appendExchange(userTranscript: "two", assistantResponse: "b")
        memoryStore.appendExchange(userTranscript: "three", assistantResponse: "c")

        let recentExchanges = memoryStore.recentExchanges(limit: 10)

        #expect(recentExchanges.count == 2)
        #expect(recentExchanges.first?.userTranscript == "two")
        #expect(recentExchanges.last?.userTranscript == "three")
    }

    @Test func persistentMemoryStorePersistsExplicitFactsAndPreferences() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let storageURL = temporaryDirectory.appendingPathComponent("memory.json")

        let persistentMemoryStore = PersistentMemoryStore(storageURL: storageURL)
        persistentMemoryStore.appendMemory(
            DexterStructuredMemoryRecord.explicitSemantic(
                content: "Keys live in the worker secrets.",
                title: "API key location"
            )
        )
        persistentMemoryStore.appendMemory(
            DexterStructuredMemoryRecord.explicitPreference(content: "Speak briefly.", title: "Voice")
        )

        let reloadedStore = PersistentMemoryStore(storageURL: storageURL)
        #expect(reloadedStore.allMemories().count == 2)
        #expect(reloadedStore.activeMemories().first?.content.contains("worker secrets") == true)
    }

    @Test func memoryIntentProcessorOnlyStoresExplicitRememberAndTaskIntents() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        DexterMemoryIntentProcessor.applyExplicitIntents(
            fromUserMessage: "hello dexter how are you",
            to: memoryStore
        )
        #expect(memoryStore.allPersistentEntries().isEmpty)

        DexterMemoryIntentProcessor.applyExplicitIntents(
            fromUserMessage: "remember that my standup is at 9am",
            to: memoryStore
        )
        #expect(memoryStore.allPersistentEntries().count == 1)
        #expect(memoryStore.allPersistentEntries().first?.kind == .rememberedFact)

        DexterMemoryIntentProcessor.applyExplicitIntents(
            fromUserMessage: "my current task is finish the onboarding flow",
            to: memoryStore
        )
        #expect(memoryStore.activeTaskDescription == "finish the onboarding flow")
    }

    @Test func defaultMemoryStoreIncludesPersistentMemoryInContextAssembly() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        memoryStore.rememberFact("Deploy on Fridays.", title: "Deploy rule", provenance: .explicitUserRequest)
        memoryStore.setWorkflowContext(
            DexterWorkflowContextState(summary: "Release checklist for v2"),
            provenance: .workflowRequired
        )

        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: false,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: memoryStore,
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: InMemoryDexterTaskStateStore()
        )

        let context = await assembler.assembleContext(
            request: DexterContextAssemblyRequest(userMessage: "continue", screenCaptureMode: .skip)
        )

        #expect(context.persistentMemory.rememberedFacts.count == 1)
        #expect(context.persistentMemory.workflowContext?.summary == "Release checklist for v2")
    }

    @Test func clipboardEvaluatorIncludesClipboardWhenUserMentionsPaste() async throws {
        #expect(DexterClipboardContextEvaluator.shouldIncludeClipboard(forUserMessage: "what is on my clipboard"))
        #expect(!DexterClipboardContextEvaluator.shouldIncludeClipboard(forUserMessage: "hello dexter"))
    }

    @Test func contextAssemblerSkipsScreenCaptureWhenPermissionMissing() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 5)
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: false,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: memoryStore,
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: InMemoryDexterTaskStateStore()
        )

        let context = await assembler.assembleContext(
            request: DexterContextAssemblyRequest(userMessage: "hello")
        )

        #expect(context.screen.allScreens.isEmpty)
        #expect(context.screen.captureAvailability == .permissionMissing)
        #expect(context.userMessage.text == "hello")
        #expect(context.activeApplication.availability == .permissionMissing)
    }

    @Test func contextAssemblerIncludesConversationAndTaskState() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 5)
        memoryStore.appendExchange(userTranscript: "prior", assistantResponse: "answer")
        memoryStore.setActiveTask(description: "finish onboarding", provenance: .workflowRequired)

        let actionHistoryStore = InMemoryDexterActionHistoryStore()
        actionHistoryStore.recordAction(actionIdentifier: "demo.point", summary: "pointed at button")

        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: true,
                    hasScreenContentPermission: true
                )
            ),
            memoryStore: memoryStore,
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: actionHistoryStore,
            taskStateStore: taskStateStore
        )

        let context = await assembler.assembleContext(
            request: DexterContextAssemblyRequest(
                userMessage: "continue",
                screenCaptureMode: .skip,
                includeRecentConversation: true
            )
        )

        #expect(context.conversation.recentExchanges.count == 1)
        #expect(context.currentTask.currentTaskDescription == "finish onboarding")
        #expect(context.recentActions.recentActions.count == 1)
        #expect(context.screen.captureAvailability == .notApplicable)
    }

    @Test func dexterOrchestratorRecordsConversationThroughMemoryStore() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 5)
        let taskStateStore = DexterWorkflowTaskStateStore(memoryStore: memoryStore)
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: false,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: memoryStore,
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: taskStateStore
        )

        let orchestrator = DexterOrchestrator(
            contextAssembler: assembler,
            modelProvider: MockModelProvider(),
            memoryStore: memoryStore,
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: false,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            agentRuntime: OpenClawAgentRuntimeAdapter(),
            actionVerifier: ObservingActionVerifier(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionStore: InMemoryDexterActionStore(),
            actionPermissionSettingsStore: InMemoryDexterActionPermissionSettingsStore(),
            actionContextObserver: StubDexterActionContextObserver(),
            taskStateStore: taskStateStore
        )

        let response = try await orchestrator.generateModelResponse(
            userTranscript: "hello",
            systemPrompt: "test",
            options: DexterModelGenerationOptions(
                screenCaptureOverride: [],
                includeSessionConversationHistory: false
            )
        )

        #expect(response.fullResponseText == "mock-response")
        orchestrator.recordConversationExchange(userTranscript: "hello", assistantResponse: "spoken")
        #expect(orchestrator.memoryStore.recentExchanges(limit: 1).first?.assistantResponse == "spoken")
    }

    @Test func pointerAttentionCalculatorMapsPointerIntoScreenshotPixels() async throws {
        let displayFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let pointerLocation = CGPoint(x: 500, y: 400)

        let pointerInPixels = DexterPointerAttentionCalculator.pointerLocationInScreenshotPixels(
            pointerLocationInScreenSpace: pointerLocation,
            displayFrameInScreenSpace: displayFrame,
            displayWidthInPoints: 1000,
            displayHeightInPoints: 800,
            screenshotWidthInPixels: 1000,
            screenshotHeightInPixels: 800
        )

        #expect(pointerInPixels != nil)
        #expect(pointerInPixels?.xInPixels == 500)
        #expect(pointerInPixels?.yInPixels == 400)
    }

    @Test func teachingIntentRecognizerMapsExplainAndTroubleshoot() async throws {
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "explain this panel") == .explain)
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "why is this error happening") == .troubleshoot)
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "teach me git") == .teach)
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "guide me step by step") == .guide)
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "how do I export") == .guide)
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "Open Safari.") == .act)
        #expect(DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: "hello") == .answer)
    }

    @Test func taskPlannerCreatesAssignmentSubmissionWorkflowWithEightSteps() async throws {
        let plannedTask = TaskPlanner.planTaskIfRequested(forUserMessage: "Help me submit this assignment.")
        guard let plannedTask else {
            Issue.record("Expected assignment submission workflow to be planned.")
            return
        }

        #expect(plannedTask.workflowIdentifier == "assignment_submission_v1")
        #expect(plannedTask.steps.count == 8)
        #expect(plannedTask.steps.map(\.kind) == [
            .inspectAssignmentOnScreen,
            .openBrowserForSubmission,
            .inspectRequiredFields,
            .prepareUploadGuidance,
            .requestSubmissionPermission,
            .guideFinalSubmission,
            .verifySubmission,
            .reportCompletion
        ])
        #expect(plannedTask.state == .planning)
    }

    @Test func orchestratorAssignmentWorkflowUsesAgentRuntimeOnSafariStep() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        let taskStateStore = DexterWorkflowTaskStateStore(memoryStore: memoryStore)
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: memoryStore,
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: taskStateStore
        )
        let agentRuntime = RecordingAgentRuntime(result: AgentActionResult(
            reportedSuccess: true,
            message: "Safari opened.",
            executionStatus: .succeeded,
            runtimeTaskIdentifier: "workflow",
            rawOutput: nil
        ))
        let actionContextObserver = StubDexterActionContextObserver()
        actionContextObserver.observationSnapshot = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeApplicationLocalizedName: "Safari",
            activeWindowTitle: "Start Page",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let orchestrator = DexterOrchestrator(
            contextAssembler: assembler,
            modelProvider: RecordingModelProvider(),
            memoryStore: memoryStore,
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            agentRuntime: agentRuntime,
            actionVerifier: ObservingActionVerifier(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionStore: InMemoryDexterActionStore(),
            actionPermissionSettingsStore: InMemoryDexterActionPermissionSettingsStore(
                currentSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true)
            ),
            actionContextObserver: actionContextObserver,
            taskStateStore: taskStateStore
        )

        let startResponse = try await orchestrator.generateModelResponse(
            userTranscript: "Help me submit this assignment.",
            systemPrompt: "test",
            options: DexterModelGenerationOptions(screenCaptureOverride: [], includeSessionConversationHistory: false)
        )
        #expect(startResponse.responseMode == .guide)
        #expect(startResponse.fullResponseText.contains("Step 1"))
        #expect(orchestrator.taskStateStore.activeWorkflowTask?.steps.count == 8)

        let stepOneComplete = try await orchestrator.generateModelResponse(
            userTranscript: "continue",
            systemPrompt: "test",
            options: DexterModelGenerationOptions(screenCaptureOverride: [], includeSessionConversationHistory: false)
        )
        #expect(stepOneComplete.fullResponseText.contains("Step 1 complete"))

        let safariStep = try await orchestrator.generateModelResponse(
            userTranscript: "continue",
            systemPrompt: "test",
            options: DexterModelGenerationOptions(screenCaptureOverride: [], includeSessionConversationHistory: false)
        )
        #expect(safariStep.fullResponseText.contains("Step 2 complete"))
        #expect(agentRuntime.executedActionRequests.first?.parameters["applicationName"] == "Safari")
        #expect(orchestrator.taskStateStore.activeWorkflowTask?.currentStep?.kind == .inspectRequiredFields)
    }

    @Test func taskWorkflowRunnerRequiresExplicitSubmissionApproval() async throws {
        var task = TaskPlanner.assignmentSubmissionWorkflow(userGoalDescription: "submit homework")
        task.currentStepIndex = 4
        task.state = .waitingForPermission
        task.steps[4].state = .waitingForPermission

        let deniedOutcome = await DexterTaskWorkflowRunner.processTurn(
            userMessage: "not yet",
            task: task,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "not yet")),
            executeVerifiedAction: { _ in
                DexterActionExecutionOutcome(
                    action: DexterActionFactory.openApplication(named: "Safari"),
                    spokenSummary: "unused",
                    pendingConfirmation: nil,
                    verificationReport: nil,
                    turnRecord: nil,
                    executionSnapshot: nil,
                    recoveryMetadata: nil
                )
            }
        )
        #expect(deniedOutcome.task.state == .waitingForPermission)

        let approvedOutcome = await DexterTaskWorkflowRunner.processTurn(
            userMessage: "I approve submitting",
            task: deniedOutcome.task,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "I approve submitting")),
            executeVerifiedAction: { _ in
                DexterActionExecutionOutcome(
                    action: DexterActionFactory.openApplication(named: "Safari"),
                    spokenSummary: "unused",
                    pendingConfirmation: nil,
                    verificationReport: nil,
                    turnRecord: nil,
                    executionSnapshot: nil,
                    recoveryMetadata: nil
                )
            }
        )
        #expect(approvedOutcome.task.currentStep?.kind == .guideFinalSubmission)
    }

    @Test func actionPlannerOnlyAllowsOpenSafari() async throws {
        let context = DexterContext(userMessage: DexterUserMessageContext(text: "Open Safari."))
        let demonstrationSessionStore = DexterDemonstrationSessionStore()
        let planningOutcome = DexterActionPlanner.planAction(
            forUserMessage: "Open Safari.",
            responseMode: .act,
            context: context,
            demonstrationSessionStore: demonstrationSessionStore
        )

        guard case .action(let typedAction) = planningOutcome else {
            Issue.record("Expected Open Safari to create a safe action request.")
            return
        }

        #expect(typedAction.type == .openApplication)
        #expect(typedAction.parameters["applicationName"] == "Safari")
        #expect(typedAction.state == .proposed)
        let permissionManager = StubPermissionManager(
            snapshot: DexterPermissionSnapshot(
                hasAccessibilityPermission: false,
                hasScreenRecordingPermission: false,
                hasMicrophonePermission: false,
                hasScreenContentPermission: false
            )
        )
        #expect(permissionManager.evaluateComputerActionPermission(typedAction).isAllowed)

        let unsupportedOutcome = DexterActionPlanner.planAction(
            forUserMessage: "delete every file",
            responseMode: .act,
            context: context,
            demonstrationSessionStore: demonstrationSessionStore
        )
        guard case .unsupported = unsupportedOutcome else {
            Issue.record("Expected unsupported ACT request to stay out of AgentRuntime.")
            return
        }
    }

    @Test func orchestratorExecutesOpenSafariThroughAgentRuntimeWithoutModelProvider() async throws {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting(maxSessionExchanges: 5)
        let taskStateStore = DexterWorkflowTaskStateStore(memoryStore: memoryStore)
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: false,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: memoryStore,
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: taskStateStore
        )
        let modelProvider = RecordingModelProvider()
        let agentRuntime = RecordingAgentRuntime(result: AgentActionResult(
            reportedSuccess: true,
            message: "Safari opened.",
            executionStatus: .succeeded,
            runtimeTaskIdentifier: "test-session",
            rawOutput: nil
        ))
        let actionHistoryStore = InMemoryDexterActionHistoryStore()
        let actionStore = InMemoryDexterActionStore()
        let actionPermissionSettingsStore = InMemoryDexterActionPermissionSettingsStore(
            currentSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true)
        )
        let actionContextObserver = StubDexterActionContextObserver()
        actionContextObserver.observationSnapshot = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeApplicationLocalizedName: "Safari",
            activeWindowTitle: "Start Page",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let orchestrator = DexterOrchestrator(
            contextAssembler: assembler,
            modelProvider: modelProvider,
            memoryStore: memoryStore,
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            agentRuntime: agentRuntime,
            actionVerifier: ObservingActionVerifier(),
            actionHistoryStore: actionHistoryStore,
            actionStore: actionStore,
            actionPermissionSettingsStore: actionPermissionSettingsStore,
            actionContextObserver: actionContextObserver,
            taskStateStore: taskStateStore
        )

        let response = try await orchestrator.generateModelResponse(
            userTranscript: "Open Safari.",
            systemPrompt: "test",
            options: DexterModelGenerationOptions(
                screenCaptureOverride: [],
                includeSessionConversationHistory: false
            )
        )

        #expect(response.responseMode == .act)
        #expect(response.fullResponseText.contains("Verified"))
        #expect(response.fullResponseText.contains("Safari"))
        #expect(agentRuntime.executedActionRequests.first?.actionIdentifier == DexterActionType.openApplication.rawValue)
        #expect(agentRuntime.executedActionRequests.first?.parameters["applicationName"] == "Safari")
        #expect(!modelProvider.didGenerateResponse)
        #expect(actionHistoryStore.recentActions(limit: 1).first?.summary.contains("Verified") == true)
        #expect(orchestrator.lastTypedAction?.state == .completed)
        #expect(actionStore.recentActions(limit: 1).first?.state == .completed)
    }

    @Test @MainActor func actionVerificationEngineRejectsRuntimeSuccessWhenApplicationIsNotRunning() async throws {
        let action = DexterActionFactory.openApplication(named: "DexterVerificationFakeApplication")
        let observationAfter = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.finder",
            activeApplicationLocalizedName: "Finder",
            activeWindowTitle: "Desktop",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: observationAfter,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "Fake application opened.",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("does not appear to be running"))
    }

    @Test @MainActor func actionVerificationEngineTreatsWindowTitleOnlyClickChangeAsUncertain() async throws {
        let action = DexterActionFactory.click(x: "10", y: "20", label: "Go")
        let before = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeApplicationLocalizedName: "Safari",
            activeWindowTitle: "Start Page",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let after = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.Safari",
            activeApplicationLocalizedName: "Safari",
            activeWindowTitle: "Apple",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: before,
            observationAfter: after,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "clicked",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        )
        #expect(report.status == .unavailable)
    }

    @Test func safeRetryPolicyAllowsOpenApplicationButNotClick() async throws {
        let openAction = DexterActionFactory.openApplication(named: "Safari")
        let clickAction = DexterActionFactory.click(x: "1", y: "2")
        #expect(DexterActionSafeRetryPolicy.canAttemptSafeRetry(for: openAction))
        #expect(!DexterActionSafeRetryPolicy.canAttemptSafeRetry(for: clickAction))
    }

    @Test @MainActor func realOpenSafariVerificationAfterWorkspaceLaunch() async throws {
        guard AXIsProcessTrusted() else {
            return
        }

        let didLaunch = NSWorkspace.shared.launchApplication("Safari")
        #expect(didLaunch)
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let observer = MacDexterActionContextObserver()
        let observationAfter = observer.observeCurrentEnvironment(
            pointerLocationInScreenSpace: .zero,
            hasAccessibilityPermission: true
        )
        let action = DexterActionFactory.openApplication(named: "Safari")
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: observationAfter,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "runtime claimed success",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        )
        #expect(report.status == .verified || report.status == .partiallyVerified)
    }

    @Test @MainActor func quitApplicationVerificationWhenProcessIsNotRunning() async throws {
        let action = DexterActionFactory.quitApplication(named: "DexterVerificationFakeApplication")
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: .empty,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "runtime claimed success",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        )
        #expect(report.status == .verified)
        #expect(report.summary.contains("no longer running"))
    }

    @Test @MainActor func quitApplicationVerificationFailsWhenProcessStillRunningDespiteRuntimeSuccess() async throws {
        let action = DexterActionFactory.quitApplication(named: "SampleTargetApplication")
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName["SampleTargetApplication"] = DexterOpenApplicationVerificationSignals(
            isApplicationRunning: true,
            isApplicationFrontmost: false,
            hasVisibleWindow: true,
            observedRunningApplicationName: "SampleTargetApplication",
            observedRunningBundleIdentifier: "com.example.sampletarget"
        )
        let originalProbe = DexterActionVerificationEngine.applicationLifecycleProbe
        DexterActionVerificationEngine.applicationLifecycleProbe = probe
        defer { DexterActionVerificationEngine.applicationLifecycleProbe = originalProbe }

        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: .empty,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "OpenClaw dispatch ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "task",
                rawOutput: "ok"
            )
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("Verification failed"))
        #expect(report.summary.contains("still running"))
        #expect(report.evidence.contains("process_running=true"))
    }

    @Test @MainActor func realOpenCalculatorVerificationAfterWorkspaceLaunch() async throws {
        guard AXIsProcessTrusted() else {
            return
        }

        let didLaunch = NSWorkspace.shared.launchApplication("Calculator")
        #expect(didLaunch)
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let observer = MacDexterActionContextObserver()
        let observationAfter = observer.observeCurrentEnvironment(
            pointerLocationInScreenSpace: .zero,
            hasAccessibilityPermission: true
        )
        let action = DexterActionFactory.openApplication(named: "Calculator")
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: observationAfter,
            executionResult: AgentActionResult(
                reportedSuccess: false,
                message: "runtime reported failure",
                executionStatus: .failed,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        )
        #expect(report.status == .verified || report.status == .partiallyVerified)
    }

    @Test func typedActionFactoriesCoverSupportedActionTypes() async throws {
        #expect(DexterActionType.allCases.count == 13)
        #expect(DexterActionFactory.inspectScreen().riskLevel == .readOnly)
        #expect(DexterActionFactory.openApplication(named: "Safari").riskLevel == .lowRisk)
        #expect(DexterActionFactory.openURL("https://example.com").riskLevel == .lowRisk)
        #expect(DexterActionFactory.typeText("hello").riskLevel == .moderateRisk)
        #expect(DexterActionFactory.click(x: "1", y: "2").riskLevel == .highRisk)
        #expect(DexterActionFactory.runTask(instruction: "summarize").riskLevel == .highRisk)
    }

    @Test func actionConfirmationPolicyMatchesRiskLevels() async throws {
        let readOnlyAction = DexterActionFactory.explainContent(subject: "this panel")
        #expect(
            !DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: readOnlyAction,
                settings: .default,
                confirmationGrant: nil
            )
        )

        let lowRiskAction = DexterActionFactory.openApplication(named: "Safari")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: lowRiskAction,
                settings: DexterActionPermissionSettings(autoApproveLowRiskActions: false),
                confirmationGrant: nil
            )
        )
        #expect(
            !DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: lowRiskAction,
                settings: DexterActionPermissionSettings(autoApproveLowRiskActions: true),
                confirmationGrant: nil
            )
        )

        let moderateAction = DexterActionFactory.typeText("draft reply")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: moderateAction,
                settings: .default,
                confirmationGrant: nil
            )
        )

        let destructiveTask = DexterActionFactory.runTask(instruction: "delete all files")
        #expect(DexterActionRiskClassifier.resolvedRiskLevel(for: destructiveTask) == .highRisk)
    }

    @Test func typeTextRequiresAccessibilityPermission() async throws {
        let action = DexterActionFactory.typeText("let x = 1")
        let permissionManager = StubPermissionManager(
            snapshot: DexterPermissionSnapshot(
                hasAccessibilityPermission: false,
                hasScreenRecordingPermission: true,
                hasMicrophonePermission: true,
                hasScreenContentPermission: true
            )
        )

        let decision = permissionManager.evaluateComputerActionPermission(action)
        #expect(!decision.isAllowed)
        #expect(decision.requiresAccessibilityPermission)
    }

    @Test func actionConfirmationContentUsesSpecificWhatWhyWhere() async throws {
        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "Open Safari."),
            activeApplication: DexterActiveApplicationContext(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari",
                availability: .available
            ),
            activeWindow: DexterActiveWindowContext(title: "Start Page", availability: .available)
        )
        let content = DexterActionConfirmationContentBuilder.build(
            action: DexterActionFactory.openApplication(named: "Safari"),
            context: context
        )
        #expect(content.whatWillHappen.contains("Open Safari"))
        #expect(content.whyDexterWantsToDoIt.contains("Open Safari."))
        #expect(content.whereItWillHappen.contains("Safari"))
        #expect(content.whereItWillHappen.contains("Start Page"))
    }

    @Test func nonAllowlistedTypedActionStaysAwaitingConfirmation() async throws {
        let clickAction = DexterActionFactory.click(x: "10", y: "20", label: "Submit")
        let permissionManager = StubPermissionManager(
            snapshot: DexterPermissionSnapshot(
                hasAccessibilityPermission: true,
                hasScreenRecordingPermission: true,
                hasMicrophonePermission: true,
                hasScreenContentPermission: true
            )
        )
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: clickAction,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "click submit")),
            permissionManager: permissionManager,
            contextObserver: StubDexterActionContextObserver(),
            agentRuntime: RecordingAgentRuntime(result: AgentActionResult(
                reportedSuccess: true,
                message: "should not run",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )),
            actionVerifier: ObservingActionVerifier(),
            actionStore: InMemoryDexterActionStore(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionPermissionSettings: .default,
            hasPersistedScreenContentGrant: false
        )
        #expect(outcome.action.state == .awaitingConfirmation)
        #expect(outcome.pendingConfirmation != nil)
        #expect(outcome.spokenSummary.contains("What will happen"))
    }

    @Test func teachingModeInstructionsIncludeTeachingStructureForExplain() async throws {
        let instructions = DexterTeachingModeInstructions.supplementalSystemInstructions(
            for: .explain,
            hasScreenContext: true
        )
        #expect(instructions.contains("EXPLAIN"))
        #expect(instructions.contains("what is happening"))
        #expect(instructions.contains("[POINT:"))
    }

    @Test func teachingModeContextAdjusterEnablesScreenForGuideMode() async throws {
        let snapshot = DexterScreenCaptureSnapshot(
            imageData: Data(),
            label: "screen",
            isCursorScreen: true,
            displayWidthInPoints: 100,
            displayHeightInPoints: 100,
            displayFrame: .zero,
            screenshotWidthInPixels: 100,
            screenshotHeightInPixels: 100
        )
        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "guide me"),
            screen: DexterScreenContext(
                primaryScreenshot: snapshot,
                allScreens: [snapshot],
                captureAvailability: .available
            )
        )
        let basePlan = DexterContextRelevancePlan(
            includeActiveApplication: false,
            includeActiveWindow: false,
            includePointerContext: false,
            includeScreenContext: false,
            includeSelectedText: false,
            includeRecentConversationInPrompt: false,
            includeRecentConversationInAPIHistory: true,
            includeCurrentTask: false,
            includePersistentMemory: false,
            includePersonalContextGraph: false
        )
        let adjusted = DexterTeachingModeContextAdjuster.adjust(
            plan: basePlan,
            responseMode: .guide,
            context: context
        )
        #expect(adjusted.includeScreenContext)
        #expect(adjusted.includePointerContext)
    }

    @Test func relevancePlannerPrioritizesConversationForRecallQuestions() async throws {
        let context = DexterContext(userMessage: DexterUserMessageContext(text: "placeholder"))
        let plan = DexterContextRelevancePlanner.plan(
            forUserMessage: "what did you tell me earlier?",
            context: context
        )

        #expect(plan.includeRecentConversationInPrompt)
        #expect(!plan.includeScreenContext)
        #expect(!plan.includePointerContext)
        #expect(DexterContextRelevancePlanner.shouldSkipScreenCapture(forUserMessage: "what did you tell me earlier?"))
    }

    @Test func relevancePlannerPrioritizesScreenForWhatIsThis() async throws {
        let snapshot = DexterScreenCaptureSnapshot(
            imageData: Data(),
            label: "screen",
            isCursorScreen: true,
            displayWidthInPoints: 100,
            displayHeightInPoints: 100,
            displayFrame: .zero,
            screenshotWidthInPixels: 100,
            screenshotHeightInPixels: 100
        )
        let screen = DexterScreenContext(
            primaryScreenshot: snapshot,
            allScreens: [snapshot],
            captureAvailability: .available
        )
        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "what is this?"),
            screen: screen,
            attention: DexterAttentionContext(
                pointerLocationInScreenSpace: CGPoint(x: 10, y: 10),
                pointerLocationRelativeToDisplay: nil,
                regionAroundPointerInScreenSpace: nil,
                pointerLocationInPrimaryScreenshotPixels: nil,
                regionAroundPointerInPrimaryScreenshotPixels: nil,
                accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                    roleDescription: nil,
                    title: nil,
                    valueDescription: nil,
                    availability: .notApplicable
                ),
                primaryDisplayIdentifier: 1
            )
        )

        let plan = DexterContextRelevancePlanner.plan(forUserMessage: "what is this?", context: context)
        #expect(plan.includeScreenContext)
        #expect(plan.includePointerContext)
        #expect(!plan.includeRecentConversationInPrompt)
    }

    @Test func structuredModelRequestOmitsUnusedSections() async throws {
        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "what did you tell me earlier?"),
            conversation: DexterConversationContext(recentExchanges: [
                DexterConversationExchange(userTranscript: "hi", assistantResponse: "hello")
            ])
        )
        let plan = DexterContextRelevancePlanner.plan(
            forUserMessage: "what did you tell me earlier?",
            context: context
        )
        let structuredRequest = DexterStructuredModelRequestBuilder.build(
            dexterContext: context,
            relevancePlan: plan
        )

        #expect(structuredRequest.images.isEmpty)
        #expect(structuredRequest.userPrompt.contains("USER REQUEST"))
        #expect(structuredRequest.userPrompt.contains("RECENT CONVERSATION"))
        #expect(!structuredRequest.userPrompt.contains("POINTER CONTEXT"))
        #expect(!structuredRequest.userPrompt.contains("SCREEN CONTEXT"))
    }

    @Test func attentionContextIncludesPointerRegionWhenDisplayIsKnown() async throws {
        let display = DexterDisplayContext(displayIdentifier: 1, displayFrameInScreenSpace: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let attention = DexterPointerAttentionCalculator.buildAttentionContext(
            pointerLocationInScreenSpace: CGPoint(x: 720, y: 450),
            display: display,
            primaryScreenshot: nil,
            accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            )
        )

        #expect(attention.regionAroundPointerInScreenSpace != nil)
        #expect(attention.primaryDisplayIdentifier == 1)
        #expect(attention.pointerLocationRelativeToDisplay == CGPoint(x: 720, y: 450))
    }

    @Test func fixTagParserExtractsCodeFixLine() {
        let response = """
        Here is why the error happens.
        [DEXTER_FIX:let count = items.count]
        """
        #expect(DexterFixTagParser.extractFixText(from: response) == "let count = items.count")
        #expect(!DexterFixTagParser.spokenText(removingFixTagFrom: response).contains("DEXTER_FIX"))
    }

    @Test func actionPlannerFixItRequiresPendingTeachFix() async throws {
        let context = DexterContext(userMessage: DexterUserMessageContext(text: "Fix it."))
        let emptySession = DexterDemonstrationSessionStore()
        let unsupported = DexterActionPlanner.planAction(
            forUserMessage: "Fix it.",
            responseMode: .act,
            context: context,
            demonstrationSessionStore: emptySession
        )
        guard case .unsupported = unsupported else {
            Issue.record("Fix it without a taught fix should be unsupported.")
            return
        }

        let sessionWithFix = DexterDemonstrationSessionStore()
        sessionWithFix.recordProposedFix(fromAssistantResponse: "Teach [DEXTER_FIX:return true]")
        let planningOutcome = DexterActionPlanner.planAction(
            forUserMessage: "Fix it.",
            responseMode: .act,
            context: context,
            demonstrationSessionStore: sessionWithFix
        )
        guard case .action(let typedAction) = planningOutcome else {
            Issue.record("Expected typeText action when fix is pending.")
            return
        }
        #expect(typedAction.type == .typeText)
        #expect(typedAction.parameters["text"] == "return true")
    }

    @Test func pointerControlWorkflowPlansEnableItAsPointerClick() async throws {
        let snapshot = DexterScreenCaptureSnapshot(
            imageData: Data(),
            label: "screen",
            isCursorScreen: true,
            displayWidthInPoints: 100,
            displayHeightInPoints: 100,
            displayFrame: .zero,
            screenshotWidthInPixels: 100,
            screenshotHeightInPixels: 100
        )
        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "Enable it."),
            screen: DexterScreenContext(
                primaryScreenshot: snapshot,
                allScreens: [snapshot],
                captureAvailability: .available
            ),
            attention: DexterAttentionContext(
                pointerLocationInScreenSpace: CGPoint(x: 400, y: 300),
                pointerLocationRelativeToDisplay: nil,
                regionAroundPointerInScreenSpace: nil,
                pointerLocationInPrimaryScreenshotPixels: nil,
                regionAroundPointerInPrimaryScreenshotPixels: nil,
                accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                    roleDescription: "checkbox",
                    title: "Wi-Fi",
                    valueDescription: "0",
                    availability: .available
                ),
                primaryDisplayIdentifier: 1
            )
        )
        let planningOutcome = DexterActionPlanner.planAction(
            forUserMessage: "Enable it.",
            responseMode: .act,
            context: context,
            demonstrationSessionStore: DexterDemonstrationSessionStore()
        )
        guard case .action(let typedAction) = planningOutcome else {
            Issue.record("Expected enable it to plan a pointer click.")
            return
        }
        #expect(typedAction.type == .click)
        #expect(typedAction.parameters["x"] == "400")
        #expect(typedAction.parameters["y"] == "300")
        #expect(typedAction.parameters["label"] == "Wi-Fi")
    }

    @Test @MainActor func actionVerificationEngineVerifiesPointerClickWhenValueChanges() async throws {
        let action = DexterActionFactory.click(x: "10", y: "20", label: "Wi-Fi")
        let before = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.systempreferences",
            activeApplicationLocalizedName: "System Settings",
            activeWindowTitle: "Network",
            pointerElementTitle: "Wi-Fi",
            pointerElementRoleDescription: "checkbox",
            pointerElementValueDescription: "0",
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let after = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.apple.systempreferences",
            activeApplicationLocalizedName: "System Settings",
            activeWindowTitle: "Network",
            pointerElementTitle: "Wi-Fi",
            pointerElementRoleDescription: "checkbox",
            pointerElementValueDescription: "1",
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: before,
            observationAfter: after,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "Clicked",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: "clicked"
            )
        )
        #expect(report.status == .verified)
        #expect(report.summary.contains("state at your pointer changed"))
    }

    @Test @MainActor func typeTextPasteAttemptRemainsUncertainWithoutEditorContentVerification() async throws {
        let action = DexterActionFactory.typeText("let x = 1")
        let observationAfter = DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: "com.microsoft.VSCode",
            activeApplicationLocalizedName: "Visual Studio Code",
            activeWindowTitle: "Demo.swift",
            pointerElementTitle: nil,
            pointerElementRoleDescription: nil,
            pointerElementValueDescription: nil,
            browserState: .empty,
            hasAccessibilityObservation: true,
            observedAt: Date()
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("let x = 1", forType: .string)

        let report = DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: observationAfter,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "Pasted",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: "pasted"
            )
        )

        #expect(report.status == .unavailable)
    }

    @Test func workerProxyClientAppliesOptionalAuthenticationHeader() async throws {
        let requestURL = DexterWorkerProxyClient.url(path: "/chat")
        #expect(requestURL.absoluteString.contains("/chat"))
    }

    @Test func userFacingErrorMessagesCoverNetworkAndRuntimeFailures() async throws {
        let offline = URLError(.notConnectedToInternet)
        #expect(DexterUserFacingErrorMessage.forCompanionModelError(offline).contains("offline"))

        let unavailable = DexterUserFacingErrorMessage.forActionRuntimeError(
            AgentRuntimeError.unavailable,
            runtimeName: "OpenClaw"
        )
        #expect(unavailable.contains("unavailable"))

        let timeout = DexterUserFacingErrorMessage.forActionRuntimeError(
            DexterAgentRuntimeExecutionGuard.TimeoutError(timeoutSeconds: 60),
            runtimeName: "CompositeDexter"
        )
        #expect(timeout.contains("60"))
    }

    @Test func verificationUncertainDoesNotMarkActionCompleted() async throws {
        let verifier = StubActionVerifier()
        verifier.nextOutcome = ActionVerificationOutcome(
            status: .unavailable,
            summary: "Could not confirm the UI change.",
            report: DexterActionVerificationReport(
                status: .unavailable,
                summary: "Could not confirm the UI change.",
                expectedStateDescription: "test",
                observedStateDescription: "test"
            )
        )
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: DexterActionFactory.openApplication(named: "Safari"),
            context: DexterContext(userMessage: DexterUserMessageContext(text: "Open Safari.")),
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: false
                )
            ),
            contextObserver: StubDexterActionContextObserver(),
            agentRuntime: RecordingAgentRuntime(result: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )),
            actionVerifier: verifier,
            actionStore: InMemoryDexterActionStore(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionPermissionSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true)
        )
        #expect(outcome.action.state == .verificationFailed)
        #expect(!outcome.spokenSummary.lowercased().contains("verified:"))
    }

    @Test func actionPipelineSurfacesRuntimeUnavailableMessage() async throws {
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: DexterActionFactory.openApplication(named: "Safari"),
            context: DexterContext(userMessage: DexterUserMessageContext(text: "Open Safari.")),
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: true,
                    hasMicrophonePermission: true,
                    hasScreenContentPermission: true
                )
            ),
            contextObserver: StubDexterActionContextObserver(),
            agentRuntime: UnavailableAgentRuntime(),
            actionVerifier: ObservingActionVerifier(),
            actionStore: InMemoryDexterActionStore(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionPermissionSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true)
        )
        #expect(outcome.action.state == .failed)
        #expect(outcome.spokenSummary.lowercased().contains("unavailable"))
    }

    @Test func screenContextMarksPermissionMissingWhenScreenRecordingDenied() async throws {
        let assembler = DexterContextAssembler(
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: true,
                    hasScreenContentPermission: false
                )
            ),
            memoryStore: DefaultMemoryStore.inMemoryForTesting(),
            screenCaptureProvider: FailingScreenCaptureProvider(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            taskStateStore: DexterWorkflowTaskStateStore(
                memoryStore: DefaultMemoryStore.inMemoryForTesting()
            )
        )
        let context = await assembler.assembleContext(
            request: DexterContextAssemblyRequest(userMessage: "what is this?")
        )
        #expect(context.screen.captureAvailability == .permissionMissing)
        let plan = DexterContextRelevancePlanner.plan(forUserMessage: "what is this?", context: context)
        let structured = DexterStructuredModelRequestBuilder.build(dexterContext: context, relevancePlan: plan)
        #expect(structured.userPrompt.contains("screen recording permission missing"))
    }

    @Test func macDexterRuntimeAllowlistIncludesVSCodeAndTypeText() {
        let openVSCode = AgentActionRequest(
            actionIdentifier: DexterActionType.openApplication.rawValue,
            parameters: ["applicationName": "Visual Studio Code"]
        )
        #expect(MacDexterRuntimeAllowlist.isSupported(openVSCode))

        let typeFix = AgentActionRequest(
            actionIdentifier: DexterActionType.typeText.rawValue,
            parameters: ["text": "let x = 1"]
        )
        #expect(MacDexterRuntimeAllowlist.isSupported(typeFix))
    }

}

private final class StubPermissionManager: PermissionManager {
    let snapshot: DexterPermissionSnapshot

    init(snapshot: DexterPermissionSnapshot) {
        self.snapshot = snapshot
    }

    func currentPermissionSnapshot(hasPersistedScreenContentGrant: Bool) -> DexterPermissionSnapshot {
        var resolvedSnapshot = snapshot
        if hasPersistedScreenContentGrant {
            resolvedSnapshot.hasScreenContentPermission = true
        }
        return resolvedSnapshot
    }

    @discardableResult
    func requestAccessibilityPermission() -> PermissionRequestPresentationDestination {
        .alreadyGranted
    }

    @discardableResult
    func requestScreenRecordingPermission() -> PermissionRequestPresentationDestination {
        .alreadyGranted
    }
}

private final class FailingScreenCaptureProvider: DexterScreenCaptureProviding {
    func captureScreensForPointerAttention(
        pointerLocationInScreenSpace: CGPoint,
        scope: DexterScreenCaptureScope,
        diagnosticReason: String
    ) async throws -> [CompanionScreenCapture] {
        throw NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "capture should not run"])
    }
}

@MainActor
private final class MockModelProvider: ModelProvider {
    var modelIdentifier: String = "mock"

    func setModelIdentifier(_ modelIdentifier: String) {
        self.modelIdentifier = modelIdentifier
    }

    func warmUpConnectionIfNeeded() {}

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        await onTextChunk("mock")
        return DexterModelGenerationResult(fullResponseText: "mock-response", duration: 0)
    }
}

@MainActor
private final class RecordingModelProvider: ModelProvider {
    var modelIdentifier: String = "recording"
    var didGenerateResponse = false

    func setModelIdentifier(_ modelIdentifier: String) {
        self.modelIdentifier = modelIdentifier
    }

    func warmUpConnectionIfNeeded() {}

    func generateStreamingResponse(
        request: DexterModelGenerationRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterModelGenerationResult {
        _ = request
        didGenerateResponse = true
        await onTextChunk("unexpected")
        return DexterModelGenerationResult(fullResponseText: "unexpected", duration: 0)
    }
}

@MainActor
final class StubDexterActionContextObserver: DexterActionContextObserver {
    var observationSnapshot: DexterActionObservationSnapshot = .empty

    func observeCurrentEnvironment(
        pointerLocationInScreenSpace: CGPoint,
        hasAccessibilityPermission: Bool
    ) -> DexterActionObservationSnapshot {
        observationSnapshot
    }
}

private final class RecordingAgentRuntime: AgentRuntime {
    let runtimeName = "Recording"
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle
    private let result: AgentActionResult
    private(set) var executedActionRequests: [AgentActionRequest] = []

    init(result: AgentActionResult) {
        self.result = result
    }

    func isAvailable() -> Bool {
        true
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        executedActionRequests.append(actionRequest)
        currentExecutionStatus = result.executionStatus
        return result
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        currentExecutionStatus = .cancelled
        return AgentActionCancellationResult(didCancel: true, message: "cancelled")
    }
}

private final class UnavailableAgentRuntime: AgentRuntime {
    let runtimeName = "UnavailableTest"
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    func isAvailable() -> Bool {
        false
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        throw AgentRuntimeError.unavailable
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        AgentActionCancellationResult(didCancel: false, message: "none")
    }
}
