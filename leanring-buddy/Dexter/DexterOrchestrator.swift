//
//  DexterOrchestrator.swift
//  leanring-buddy
//
//  Central coordinator for context, memory, model generation, and (future) agent actions.
//

import CoreGraphics
import Foundation

struct DexterModelGenerationOptions: Equatable {
    /// When set, uses these snapshots instead of live screen capture.
    var screenCaptureOverride: [DexterScreenCaptureSnapshot]?
    /// When false, the model request is sent without prior conversation turns.
    var includeSessionConversationHistory: Bool
    /// Passed through for screen-content permission bookkeeping in context assembly.
    var hasPersistedScreenContentGrant: Bool
    var pointerLocationInScreenSpaceOverride: CGPoint?
    var usePointAtContextRelevancePlan: Bool

    nonisolated init(
        screenCaptureOverride: [DexterScreenCaptureSnapshot]? = nil,
        includeSessionConversationHistory: Bool = true,
        hasPersistedScreenContentGrant: Bool = false,
        pointerLocationInScreenSpaceOverride: CGPoint? = nil,
        usePointAtContextRelevancePlan: Bool = false
    ) {
        self.screenCaptureOverride = screenCaptureOverride
        self.includeSessionConversationHistory = includeSessionConversationHistory
        self.hasPersistedScreenContentGrant = hasPersistedScreenContentGrant
        self.pointerLocationInScreenSpaceOverride = pointerLocationInScreenSpaceOverride
        self.usePointAtContextRelevancePlan = usePointAtContextRelevancePlan
    }
}

struct DexterOrchestratorModelResponse: Equatable {
    let fullResponseText: String
    let context: DexterContext
    let responseMode: DexterResponseMode
}

@MainActor
final class DexterOrchestrator {
    private(set) var lastAssembledContext: DexterContext?
    private(set) var lastResponseMode: DexterResponseMode = .answer

    let contextAssembler: DexterContextAssembler
    let modelProvider: ModelProvider
    let memoryStore: MemoryStore
    let permissionManager: PermissionManager
    let agentRuntime: AgentRuntime
    let actionVerifier: ActionVerifier
    let actionHistoryStore: DexterActionHistoryStore
    let actionStore: DexterActionStore
    let actionPermissionSettingsStore: DexterActionPermissionSettingsStore
    let actionContextObserver: DexterActionContextObserver
    let taskStateStore: DexterTaskStateStore
    let demonstrationPhaseStore: DexterDemonstrationPhaseStore?
    let demonstrationSessionStore: DexterDemonstrationSessionStore

    private(set) var lastTypedAction: DexterAction?
    private(set) var pendingActionExecution: DexterPendingActionExecution?

    init(
        contextAssembler: DexterContextAssembler,
        modelProvider: ModelProvider,
        memoryStore: MemoryStore,
        permissionManager: PermissionManager,
        agentRuntime: AgentRuntime,
        actionVerifier: ActionVerifier,
        actionHistoryStore: DexterActionHistoryStore,
        actionStore: DexterActionStore,
        actionPermissionSettingsStore: DexterActionPermissionSettingsStore,
        actionContextObserver: DexterActionContextObserver,
        taskStateStore: DexterTaskStateStore,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        demonstrationSessionStore: DexterDemonstrationSessionStore? = nil
    ) {
        self.contextAssembler = contextAssembler
        self.modelProvider = modelProvider
        self.memoryStore = memoryStore
        self.permissionManager = permissionManager
        self.agentRuntime = agentRuntime
        self.actionVerifier = actionVerifier
        self.actionHistoryStore = actionHistoryStore
        self.actionStore = actionStore
        self.actionPermissionSettingsStore = actionPermissionSettingsStore
        self.actionContextObserver = actionContextObserver
        self.taskStateStore = taskStateStore
        self.demonstrationPhaseStore = demonstrationPhaseStore
        self.demonstrationSessionStore = demonstrationSessionStore ?? DexterDemonstrationSessionStore()
    }

    var actionPermissionSettings: DexterActionPermissionSettings {
        get { actionPermissionSettingsStore.currentSettings }
        set { actionPermissionSettingsStore.currentSettings = newValue }
    }

    func actionConfirmationPresentation() -> DexterActionConfirmationPresentation? {
        guard let pendingActionExecution else { return nil }
        let resolvedRiskLevel = DexterActionRiskClassifier.resolvedRiskLevel(for: pendingActionExecution.action)
        return DexterActionConfirmationPresentation(
            actionId: pendingActionExecution.action.id,
            riskLevel: resolvedRiskLevel,
            content: pendingActionExecution.confirmationContent
        )
    }

    func cancelInFlightComputerActionIfNeeded() async {
        _ = await agentRuntime.cancelCurrentAction()
    }

    func cancelPendingActionConfirmation() {
        pendingActionExecution = nil
        demonstrationPhaseStore?.transition(to: .done, detail: "Action cancelled")
        if let lastTypedAction, lastTypedAction.state == .awaitingConfirmation {
            let cancelledAction = lastTypedAction.withState(.cancelled)
            self.lastTypedAction = cancelledAction
            actionStore.update(cancelledAction)
        }
    }

    @discardableResult
    func approvePendingActionConfirmation() async -> DexterActionExecutionOutcome? {
        guard !Task.isCancelled else { return nil }
        guard let pendingActionExecution else { return nil }
        let confirmationGrant = DexterActionConfirmationGrant(
            actionId: pendingActionExecution.action.id,
            riskLevelAtApprovalTime: DexterActionRiskClassifier.resolvedRiskLevel(for: pendingActionExecution.action)
        )
        self.pendingActionExecution = nil
        return await executeVerifiedAction(
            proposedAction: pendingActionExecution.action,
            context: pendingActionExecution.context,
            hasPersistedScreenContentGrant: pendingActionExecution.hasPersistedScreenContentGrant,
            confirmationGrant: confirmationGrant
        )
    }

    func setModelIdentifier(_ modelIdentifier: String) {
        modelProvider.setModelIdentifier(modelIdentifier)
    }

    func warmUpModelConnectionIfNeeded() {
        modelProvider.warmUpConnectionIfNeeded()
    }

    func recordConversationExchange(userTranscript: String, assistantResponse: String) {
        memoryStore.appendExchange(userTranscript: userTranscript, assistantResponse: assistantResponse)
    }

    func developmentContextInspectorSnapshotIfEnabled(for context: DexterContext) -> DexterDevelopmentContextInspectorSnapshot? {
        guard DexterDevelopmentContextInspectorSettings.isEnabled else { return nil }
        return DexterDevelopmentContextInspectorSnapshot(context: context)
    }

    /// Captures pointer, screen, and environment context for POINT → ASK (in-memory only).
    func preparePointInvokeSession(
        pointerLocationInScreenSpace: CGPoint,
        hasPersistedScreenContentGrant: Bool
    ) async -> DexterPointInvokeSession {
        let assemblyRequest = DexterContextAssemblyRequest(
            userMessage: "",
            screenCaptureMode: .captureAllDisplaysIfPermitted,
            includeRecentConversation: false,
            recentConversationLimit: 0,
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
            pointerLocationInScreenSpaceOverride: pointerLocationInScreenSpace
        )

        let dexterContext = await contextAssembler.assembleContext(request: assemblyRequest)
        let permissionSnapshot = permissionManager.currentPermissionSnapshot(
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
        )

        let contextSnapshot = DexterContextSnapshotBuilder.make(
            from: dexterContext,
            permissionState: DexterContextPermissionState(
                hasScreenRecordingPermission: permissionSnapshot.hasScreenRecordingPermission,
                hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
                hasScreenContentPermission: permissionSnapshot.hasScreenContentPermission
            ),
            userRequestedScreenContext: true
        )

        return DexterPointInvokeSession(
            pointerLocationInScreenSpace: pointerLocationInScreenSpace,
            capturedAt: Date(),
            contextSnapshot: contextSnapshot,
            screenCaptureSnapshots: dexterContext.screen.allScreens
        )
    }

    /// Generates a model response using the configured provider.
    /// Session conversation is appended only via `recordConversationExchange`.
    /// Persistent memory changes only through explicit user intents or workflow state APIs.
    func generateModelResponse(
        userTranscript: String,
        systemPrompt: String,
        options: DexterModelGenerationOptions = DexterModelGenerationOptions(),
        onTextChunk: @escaping @MainActor @Sendable (String) -> Void = { _ in }
    ) async throws -> DexterOrchestratorModelResponse {
        DexterMemoryIntentProcessor.applyExplicitIntents(fromUserMessage: userTranscript, to: memoryStore)

        demonstrationPhaseStore?.transition(
            to: .seeing,
            detail: "Screenshot, pointer, active app, and window"
        )

        let screenCaptureMode: DexterScreenCaptureMode
        if let screenCaptureOverride = options.screenCaptureOverride {
            screenCaptureMode = .useOverride(screenCaptureOverride)
        } else if options.usePointAtContextRelevancePlan {
            screenCaptureMode = .captureAllDisplaysIfPermitted
        } else if DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: userTranscript) {
            screenCaptureMode = .captureCursorDisplayIfPermitted
        } else if DexterContextRelevancePlanner.shouldSkipScreenCapture(forUserMessage: userTranscript) {
            screenCaptureMode = .skip
        } else {
            screenCaptureMode = .skip
        }

        if screenCaptureMode != .skip {
            DexterVisionTiming.beginVisionTurn()
        }

        switch screenCaptureMode {
        case .skip:
            DexterTurnTrace.log("screen capture mode=skip")
        case .captureCursorDisplayIfPermitted:
            DexterTurnTrace.log("screen capture mode=cursorDisplay")
        case .captureAllDisplaysIfPermitted:
            DexterTurnTrace.log("screen capture mode=allDisplays")
        case .useOverride:
            DexterTurnTrace.log("screen capture mode=override")
        }

        let assemblyRequest = DexterContextAssemblyRequest(
            userMessage: userTranscript,
            screenCaptureMode: screenCaptureMode,
            includeRecentConversation: options.includeSessionConversationHistory,
            recentConversationLimit: 10,
            hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
            pointerLocationInScreenSpaceOverride: options.pointerLocationInScreenSpaceOverride
        )

        DexterTurnTrace.log("context assembly started")
        DexterDiagnosticLog.context("context assembly started")
        DexterTurnTrace.log("awaiting context")
        let dexterContext = try await DexterAsyncTimeout.withTimeout(seconds: 45) { [self] in
            await contextAssembler.assembleContext(request: assemblyRequest)
        }
        lastAssembledContext = dexterContext
        DexterTurnTrace.log("context returned")
        DexterTurnTrace.log("context assembly completed")
        DexterDiagnosticLog.context("context assembly finished")

        demonstrationPhaseStore?.transition(to: .thinking, detail: "Understanding your request")

        let responseMode = DexterTeachingIntentRecognizer.recognizeResponseMode(forUserMessage: userTranscript)
        lastResponseMode = responseMode

        if responseMode == .act {
            DexterActionDiagnosticLog.action("intent detected")
            if !DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled {
                let unavailableMessage =
                    "Local computer control is currently unavailable. Dexter can still chat and explain your screen."
                demonstrationPhaseStore?.transition(to: .done, detail: unavailableMessage)
                await onTextChunk(unavailableMessage)
                return DexterOrchestratorModelResponse(
                    fullResponseText: unavailableMessage,
                    context: dexterContext,
                    responseMode: responseMode
                )
            }

            if let actionResponse = await handleActionRequestIfNeeded(
                userTranscript: userTranscript,
                responseMode: responseMode,
                context: dexterContext,
                hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
                onTextChunk: onTextChunk
            ) {
                return actionResponse
            }

            let unresolvedActionMessage =
                "I understood that as a computer action, but Dexter couldn't execute it safely."
            demonstrationPhaseStore?.transition(to: .done, detail: unresolvedActionMessage)
            await onTextChunk(unresolvedActionMessage)
            return DexterOrchestratorModelResponse(
                fullResponseText: unresolvedActionMessage,
                context: dexterContext,
                responseMode: responseMode
            )
        }

        if DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled {
            if let workflowResponse = await handleWorkflowTaskIfNeeded(
                userTranscript: userTranscript,
                context: dexterContext,
                hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
                onTextChunk: onTextChunk
            ) {
                return workflowResponse
            }
        }

        var relevancePlan: DexterContextRelevancePlan
        if options.usePointAtContextRelevancePlan {
            relevancePlan = DexterContextRelevancePlanner.planForPointAtInvocation(context: dexterContext)
        } else {
            relevancePlan = DexterContextRelevancePlanner.plan(
                forUserMessage: userTranscript,
                context: dexterContext
            )
        }
        relevancePlan = DexterTeachingModeContextAdjuster.adjust(
            plan: relevancePlan,
            responseMode: responseMode,
            context: dexterContext
        )

        let structuredModelRequest = DexterStructuredModelRequestBuilder.build(
            dexterContext: dexterContext,
            relevancePlan: relevancePlan
        )

        let userRequestedScreenContext = options.usePointAtContextRelevancePlan
            || DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: userTranscript)

        let teachingInstructions = DexterTeachingModeInstructions.supplementalSystemInstructions(
            for: responseMode,
            hasScreenContext: !structuredModelRequest.images.isEmpty
        )

        let honestyInstructions = DexterContextHonestyInstructions.supplementalSystemInstructions(
            userRequestedScreenContext: userRequestedScreenContext,
            screenCaptureAvailability: dexterContext.screen.captureAvailability,
            hasAttachedScreenshot: !structuredModelRequest.images.isEmpty
        )

        let combinedSystemPrompt: String = [
            systemPrompt,
            teachingInstructions,
            honestyInstructions
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let generationRequest = DexterModelGenerationRequest(
            systemPrompt: combinedSystemPrompt,
            userPrompt: structuredModelRequest.userPrompt,
            images: structuredModelRequest.images,
            conversationHistory: structuredModelRequest.conversationHistory,
            userRequestedScreenContext: userRequestedScreenContext,
            screenCaptureAvailability: dexterContext.screen.captureAvailability
        )

        let modelTimeoutSeconds: TimeInterval = generationRequest.images.isEmpty ? 120 : 90
        DexterTurnTrace.log("visualContextRequired=\(!generationRequest.images.isEmpty)")
        DexterTurnTrace.log("screenshot/images in request: \(generationRequest.images.count)")
        DexterDiagnosticLog.model("generation started (images: \(generationRequest.images.count))")
        DexterTurnTrace.log("awaiting model (timeout \(Int(modelTimeoutSeconds))s)")
        DexterTurnTrace.log("model request started")
        let generationResult = try await DexterAsyncTimeout.withTimeout(seconds: modelTimeoutSeconds) { [self] in
            try await modelProvider.generateStreamingResponse(
                request: generationRequest,
                onTextChunk: onTextChunk
            )
        }
        DexterTurnTrace.log("model returned")
        DexterTurnTrace.log("model response received")
        DexterDiagnosticLog.model("generation finished")

        demonstrationPhaseStore?.transition(to: .done, detail: "Response ready")

        return DexterOrchestratorModelResponse(
            fullResponseText: generationResult.fullResponseText,
            context: dexterContext,
            responseMode: responseMode
        )
    }

    /// Permission-gated ACT step: PLAN → PERMISSION → EXECUTE → OBSERVE → VERIFY → REPORT.
    func executeVerifiedAction(
        proposedAction: DexterAction,
        context: DexterContext,
        hasPersistedScreenContentGrant: Bool = false,
        confirmationGrant: DexterActionConfirmationGrant? = nil
    ) async -> DexterActionExecutionOutcome {
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: proposedAction,
            context: context,
            permissionManager: permissionManager,
            contextObserver: actionContextObserver,
            agentRuntime: agentRuntime,
            actionVerifier: actionVerifier,
            actionStore: actionStore,
            actionHistoryStore: actionHistoryStore,
            actionPermissionSettings: actionPermissionSettingsStore.currentSettings,
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
            confirmationGrant: confirmationGrant,
            demonstrationPhaseStore: demonstrationPhaseStore
        )
        lastTypedAction = outcome.action
        pendingActionExecution = outcome.pendingConfirmation
        return outcome
    }

    private func handleWorkflowTaskIfNeeded(
        userTranscript: String,
        context: DexterContext,
        hasPersistedScreenContentGrant: Bool,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async -> DexterOrchestratorModelResponse? {
        let hasActiveWorkflow = taskStateStore.activeWorkflowTask?.isTerminal == false
        if !hasActiveWorkflow, let plannedTask = TaskPlanner.planTaskIfRequested(forUserMessage: userTranscript) {
            taskStateStore.activeWorkflowTask = plannedTask
        }

        guard let activeWorkflowTask = taskStateStore.activeWorkflowTask,
              !activeWorkflowTask.isTerminal else {
            return nil
        }

        let workflowOutcome = await DexterTaskWorkflowRunner.processTurn(
            userMessage: userTranscript,
            task: activeWorkflowTask,
            context: context,
            executeVerifiedAction: { proposedAction in
                await executeVerifiedAction(
                    proposedAction: proposedAction,
                    context: context,
                    hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
                )
            }
        )

        taskStateStore.activeWorkflowTask = workflowOutcome.task

        guard workflowOutcome.didHandleTurn else {
            return nil
        }

        await onTextChunk(workflowOutcome.spokenSummary)
        return DexterOrchestratorModelResponse(
            fullResponseText: workflowOutcome.spokenSummary,
            context: context,
            responseMode: .guide
        )
    }

    private func handleActionRequestIfNeeded(
        userTranscript: String,
        responseMode: DexterResponseMode,
        context: DexterContext,
        hasPersistedScreenContentGrant: Bool,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async -> DexterOrchestratorModelResponse? {
        demonstrationPhaseStore?.transition(to: .planning, detail: "Planning a safe action")

        let planningOutcome = DexterActionPlanner.planAction(
            forUserMessage: userTranscript,
            responseMode: responseMode,
            context: context,
            demonstrationSessionStore: demonstrationSessionStore
        )

        switch planningOutcome {
        case .notAnAction:
            return nil

        case .unsupported(let message):
            demonstrationPhaseStore?.transition(to: .done, detail: message)
            await onTextChunk(message)
            return DexterOrchestratorModelResponse(
                fullResponseText: message,
                context: context,
                responseMode: responseMode
            )

        case .action(let proposedAction):
            if let targetApplicationName = proposedAction.parameters["applicationName"] {
                DexterActionDiagnosticLog.intent("type=\(proposedAction.type.rawValue) target=\(targetApplicationName)")
            } else {
                DexterActionDiagnosticLog.intent("type=\(proposedAction.type.rawValue)")
            }
            DexterActionDiagnosticLog.plan("action=\(proposedAction.humanReadableDescription)")

            let outcome = await executeVerifiedAction(
                proposedAction: proposedAction,
                context: context,
                hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
            )
            DexterActionDiagnosticLog.action("completed state=\(outcome.action.state.rawValue)")
            await onTextChunk(outcome.spokenSummary)
            return DexterOrchestratorModelResponse(
                fullResponseText: outcome.spokenSummary,
                context: context,
                responseMode: responseMode
            )
        }
    }
}

@MainActor
enum DexterOrchestratorFactory {
    static func makeDefault(
        ollamaProvider: OllamaProvider,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        demonstrationSessionStore: DexterDemonstrationSessionStore? = nil
    ) -> DexterOrchestrator {
        let modelProvider = OllamaModelProviderAdapter(aiProvider: ollamaProvider)
        let memoryStore = DefaultMemoryStore(maxSessionExchanges: 10)
        let taskStateStore = DexterWorkflowTaskStateStore(memoryStore: memoryStore)
        let permissionManager = DexterPermissionManager()
        let actionHistoryStore = InMemoryDexterActionHistoryStore()
        let actionStore = InMemoryDexterActionStore()
        let actionPermissionSettingsStore = UserDefaultsDexterActionPermissionSettingsStore()
        let screenCaptureProvider = CompanionScreenCaptureProvider()
        let contextAssembler = DexterContextAssembler(
            permissionManager: permissionManager,
            memoryStore: memoryStore,
            screenCaptureProvider: screenCaptureProvider,
            actionHistoryStore: actionHistoryStore,
            taskStateStore: taskStateStore
        )
        let agentRuntime = CompositeDexterAgentRuntime()
        let actionVerifier = ObservingActionVerifier()
        let actionContextObserver = MacDexterActionContextObserver()

        return DexterOrchestrator(
            contextAssembler: contextAssembler,
            modelProvider: modelProvider,
            memoryStore: memoryStore,
            permissionManager: permissionManager,
            agentRuntime: agentRuntime,
            actionVerifier: actionVerifier,
            actionHistoryStore: actionHistoryStore,
            actionStore: actionStore,
            actionPermissionSettingsStore: actionPermissionSettingsStore,
            actionContextObserver: actionContextObserver,
            taskStateStore: taskStateStore,
            demonstrationPhaseStore: demonstrationPhaseStore,
            demonstrationSessionStore: demonstrationSessionStore ?? DexterDemonstrationSessionStore()
        )
    }
}
