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
    var routingDecision: DexterRequestRoutingDecision?
    var activeDexterProfileId: UUID?
    var activeFileWorkspaceId: UUID?

    nonisolated init(
        screenCaptureOverride: [DexterScreenCaptureSnapshot]? = nil,
        includeSessionConversationHistory: Bool = true,
        hasPersistedScreenContentGrant: Bool = false,
        pointerLocationInScreenSpaceOverride: CGPoint? = nil,
        usePointAtContextRelevancePlan: Bool = false,
        routingDecision: DexterRequestRoutingDecision? = nil,
        activeDexterProfileId: UUID? = nil,
        activeFileWorkspaceId: UUID? = nil
    ) {
        self.screenCaptureOverride = screenCaptureOverride
        self.includeSessionConversationHistory = includeSessionConversationHistory
        self.hasPersistedScreenContentGrant = hasPersistedScreenContentGrant
        self.pointerLocationInScreenSpaceOverride = pointerLocationInScreenSpaceOverride
        self.usePointAtContextRelevancePlan = usePointAtContextRelevancePlan
        self.routingDecision = routingDecision
        self.activeDexterProfileId = activeDexterProfileId
        self.activeFileWorkspaceId = activeFileWorkspaceId
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
    private(set) var lastIntentEngineResult: DexterIntentEngineResult?
    private(set) var lastVisionResponse: DexterVisionResponse?
    private(set) var lastTeachingEngineResult: DexterTeachingEngineResult?
    private(set) var lastSkillEngineResult: DexterSkillEngineResult?

    let contextAssembler: DexterContextAssembler
    let teachingSessionStore: DexterTeachingSessionStore
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
    let executionStateMachineRegistry: DexterExecutionStateMachineRegistry
    let toolRegistryGateway: DexterToolRegistryGateway
    private(set) var lastExecutionSnapshot: DexterExecutionMachineSnapshot?
    let proactiveAutomationSettingsStore: DexterProactiveAutomationSettingsStore
    private(set) var lastProactivePipelineOutcome: DexterProactivePipelineOutcome?
    let workspaceSnapshotStore: DexterWorkspaceSnapshotStore
    let fileWorkspaceStore: DexterFileWorkspaceStore
    let actionRecoveryLedger: DexterActionRecoveryLedger
    weak var activityRecorder: DexterActivityRecorder?
    var activityLinkageProvider: (() -> DexterActivityLinkage)?

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
        demonstrationSessionStore: DexterDemonstrationSessionStore? = nil,
        executionStateMachineRegistry: DexterExecutionStateMachineRegistry? = nil,
        toolRegistryGateway: DexterToolRegistryGateway? = nil,
        teachingSessionStore: DexterTeachingSessionStore? = nil,
        proactiveAutomationSettingsStore: DexterProactiveAutomationSettingsStore? = nil,
        workspaceSnapshotStore: DexterWorkspaceSnapshotStore? = nil,
        fileWorkspaceStore: DexterFileWorkspaceStore? = nil,
        actionRecoveryLedger: DexterActionRecoveryLedger? = nil
    ) {
        self.contextAssembler = contextAssembler
        self.teachingSessionStore = teachingSessionStore ?? DexterTeachingSessionStore()
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
        self.executionStateMachineRegistry = executionStateMachineRegistry ?? DexterExecutionStateMachineRegistry()
        let resolvedPermissionManager = permissionManager
        self.toolRegistryGateway = toolRegistryGateway ?? DexterToolRegistryGateway(
            permissionSnapshotProvider: {
                resolvedPermissionManager.currentPermissionSnapshot(hasPersistedScreenContentGrant: false)
            }
        )
        self.proactiveAutomationSettingsStore = proactiveAutomationSettingsStore
            ?? UserDefaultsDexterProactiveAutomationSettingsStore()
        self.workspaceSnapshotStore = workspaceSnapshotStore ?? DexterWorkspaceSnapshotStore()
        self.fileWorkspaceStore = fileWorkspaceStore ?? DexterFileWorkspaceStore()
        self.actionRecoveryLedger = actionRecoveryLedger ?? DexterActionRecoveryLedger()

        if let runtimeUIStateStore = demonstrationPhaseStore {
            self.executionStateMachineRegistry.onExecutionSnapshotChanged = { snapshot in
                runtimeUIStateStore.applyExecutionSnapshot(snapshot)
            }
        }
    }

    func setProactiveAutomationEnabled(for eventKind: DexterProactiveEventKind, isEnabled: Bool) {
        var registrations = proactiveAutomationSettingsStore.automationRegistrations
        guard let index = registrations.firstIndex(where: { $0.eventKind == eventKind }) else { return }
        registrations[index].isExplicitlyEnabledByUser = isEnabled
        proactiveAutomationSettingsStore.automationRegistrations = registrations
    }

    /// Proactive foundation: detect → explain → suggest → ask permission (execute only when explicitly enabled + granted).
    func evaluateProactiveSignals(
        detectionInput: DexterProactiveDetectionInput,
        context: DexterContext,
        userGrantedProactiveExecution: Bool = false
    ) async -> DexterProactivePipelineOutcome? {
        let outcome = await DexterProactiveFoundationEngine.detectAndProcessFirstEvent(
            detectionInput: detectionInput,
            context: context,
            automationRegistrations: proactiveAutomationSettingsStore.automationRegistrations,
            userGrantedProactiveExecution: userGrantedProactiveExecution,
            executeVerifiedAction: { [weak self] proposedAction in
                guard let self else {
                    return DexterActionExecutionOutcome(
                        action: proposedAction.withState(.failed),
                        spokenSummary: "Dexter is unavailable.",
                        pendingConfirmation: nil,
                        verificationReport: nil,
                        turnRecord: nil,
                        executionSnapshot: nil,
                        recoveryMetadata: nil
                    )
                }
                return await executeVerifiedAction(
                    proposedAction: proposedAction,
                    context: context
                )
            }
        )
        lastProactivePipelineOutcome = outcome
        return outcome
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
        if let latestExecutionIdentifier = lastExecutionSnapshot?.executionIdentifier {
            executionStateMachineRegistry.requestCancellation(forExecutionIdentifier: latestExecutionIdentifier)
            try? executionStateMachineRegistry
                .machine(forExecutionIdentifier: latestExecutionIdentifier)?
                .cancel(message: "Dexter stopped the in-flight action.")
        }
        _ = await agentRuntime.cancelCurrentAction()
        _ = await toolRegistryGateway.cancelInFlightExecution()
    }

    /// Global emergency stop: cancel automation, pending actions, and agent/tool loops.
    func activateGlobalEmergencyStop() async {
        DexterUserTrustControls.disableDexterAutomation(emergencyStopController: DexterEmergencyStopController.shared)
        cancelPendingActionConfirmation()
        await cancelInFlightComputerActionIfNeeded()
        DexterUserTrustControls.revokeActionAutoApprove(actionPermissionSettingsStore: actionPermissionSettingsStore)
        DexterUserTrustControls.revokeProactiveAutomations(settingsStore: proactiveAutomationSettingsStore)
        demonstrationPhaseStore?.transition(to: .cancelled, detail: "Emergency stop")
    }

    func recoverDexterToSafeIdle(stopSpokenOutput: () -> Void) async -> String {
        await DexterTrustRecoveryEngine.recoverToSafeIdle(
            emergencyStopController: DexterEmergencyStopController.shared,
            clearPendingConfirmations: { cancelPendingActionConfirmation() },
            cancelInFlightActions: { await cancelInFlightComputerActionIfNeeded() },
            stopSpokenOutput: stopSpokenOutput
        )
    }

    func clearDexterMemoryAndRevokeAutomationPreferences() {
        DexterUserTrustControls.clearAllDexterMemory(memoryStore: memoryStore)
        DexterUserTrustControls.revokeActionAutoApprove(actionPermissionSettingsStore: actionPermissionSettingsStore)
        DexterUserTrustControls.revokeProactiveAutomations(settingsStore: proactiveAutomationSettingsStore)
    }

    func releaseEmergencyStopAfterUserAcknowledgement() {
        DexterEmergencyStopController.shared.releaseEmergencyStopAfterUserAcknowledgement()
    }

    func cancelPendingActionConfirmation() {
        if let executionIdentifier = pendingActionExecution?.executionIdentifier {
            executionStateMachineRegistry.requestCancellation(forExecutionIdentifier: executionIdentifier)
            try? executionStateMachineRegistry
                .machine(forExecutionIdentifier: executionIdentifier)?
                .cancel(message: "You cancelled the pending action.")
        }
        pendingActionExecution = nil
        demonstrationPhaseStore?.transition(to: .cancelled, detail: "Action cancelled")
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
        let pending = pendingActionExecution
        self.pendingActionExecution = nil
        let resumedStateMachine = pending.executionIdentifier.flatMap {
            executionStateMachineRegistry.machine(forExecutionIdentifier: $0)
        }
        resumedStateMachine?.acknowledgePermissionApproval()
        if DexterComputerControlAuthorizationScope.actionQualifiesForSessionReuse(pending.action) {
            actionPermissionSettingsStore.isComputerControlAuthorizedForSession = true
        }
        return await executeVerifiedAction(
            proposedAction: pending.action,
            context: pending.context,
            hasPersistedScreenContentGrant: pending.hasPersistedScreenContentGrant,
            confirmationGrant: confirmationGrant,
            executionStateMachine: resumedStateMachine
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
            screenCaptureSnapshots: dexterContext.screen.allScreens,
            pointerSemanticTarget: dexterContext.pointer?.semanticTarget
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
        applyMemoryBinding(from: options)
        memoryStore.observeUserMessageForInference(userTranscript)
        let memoryIntentOutcome = memoryStore.processMemoryIntents(fromUserMessage: userTranscript)
        switch memoryIntentOutcome {
        case .userFacingResponse:
            DexterObservabilityLog.memory("intent_outcome=user_facing_response")
        case .appliedSilently:
            DexterObservabilityLog.memory("intent_outcome=applied_silently")
        case .inferenceConfirmationPrompt:
            DexterObservabilityLog.memory("intent_outcome=inference_confirmation_prompt")
        case .noMemoryIntent:
            break
        }
        if case .userFacingResponse(let memoryResponse) = memoryIntentOutcome {
            demonstrationPhaseStore?.transition(to: .done, detail: "Memory")
            await onTextChunk(memoryResponse)
            return DexterOrchestratorModelResponse(
                fullResponseText: memoryResponse,
                context: DexterContext(userMessage: DexterUserMessageContext(text: userTranscript)),
                responseMode: .answer
            )
        }

        demonstrationPhaseStore?.transition(
            to: DexterDemonstrationPhase.seeing,
            detail: "Screenshot, pointer, active app, and window"
        )

        let screenCaptureMode: DexterScreenCaptureMode
        if let screenCaptureOverride = options.screenCaptureOverride {
            screenCaptureMode = .useOverride(screenCaptureOverride)
        } else if options.usePointAtContextRelevancePlan {
            screenCaptureMode = .captureAllDisplaysIfPermitted
        } else if let routingDecision = options.routingDecision {
            screenCaptureMode = routingDecision.requiresScreenCapture
                ? .captureCursorDisplayIfPermitted
                : .skip
        } else if DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: userTranscript) {
            screenCaptureMode = .captureCursorDisplayIfPermitted
        } else {
            screenCaptureMode = .skip
        }

        if screenCaptureMode != .skip {
            DexterVisionTiming.beginVisionTurn()
        }

        if let routingDecision = options.routingDecision {
            DexterTurnTrace.log("request_route=\(routingDecision.route.rawValue)")
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

        let contextPerformanceProfile: DexterContextPerformanceProfile = {
            if let routingDecision = options.routingDecision {
                return routingDecision.contextPerformanceProfile
            }
            return DexterTrivialQuestionClassifier.isTrivialQuestion(userTranscript) ? .minimal : .standard
        }()

        let assemblyRequest = DexterContextAssemblyRequest(
            userMessage: userTranscript,
            screenCaptureMode: screenCaptureMode,
            includeRecentConversation: options.includeSessionConversationHistory,
            recentConversationLimit: 8,
            hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
            pointerLocationInScreenSpaceOverride: options.pointerLocationInScreenSpaceOverride,
            performanceProfile: contextPerformanceProfile,
            activeDexterProfileId: options.activeDexterProfileId,
            activeFileWorkspaceId: options.activeFileWorkspaceId
        )

        DexterTurnTrace.log("context assembly started")
        DexterDiagnosticLog.context("context assembly started")
        DexterTurnTrace.log("awaiting context")
        let assemblyResult = try await DexterTaskTraceRecorder.shared.measure(bucket: .context) {
            try await DexterAsyncTimeout.withTimeout(seconds: 45) { [self] in
                await contextAssembler.assembleContextPacket(request: assemblyRequest)
            }
        }
        var dexterContext = assemblyResult.legacyContext
        if let profileId = options.activeDexterProfileId {
            dexterContext = DexterFileWorkspaceContextProvider.attachWorkspaceContext(
                to: dexterContext,
                profileId: profileId,
                userMessage: userTranscript,
                store: fileWorkspaceStore
            )
        }
        let contextPacket = assemblyResult.packet
        lastAssembledContext = dexterContext
        DexterTurnTrace.log("context returned")
        DexterTurnTrace.log("context assembly completed")
        DexterDiagnosticLog.context("context assembly finished")
        DexterPerformanceTiming.markContextAssemblyCompleted()

        if let workspaceResponse = await handleWorkspaceIntentIfNeeded(
            userTranscript: userTranscript,
            dexterContext: dexterContext,
            contextPacket: contextPacket,
            hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
            onTextChunk: onTextChunk
        ) {
            return workspaceResponse
        }

        if let undoResponse = await handleActionUndoIfNeeded(
            userTranscript: userTranscript,
            dexterContext: dexterContext,
            hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
            onTextChunk: onTextChunk
        ) {
            return undoResponse
        }

        if let accountabilityQueryKind = DexterAccountabilityIntentRecognizer.recognizeQuery(
            fromUserMessage: userTranscript
        ) {
            let accountabilityResponse = DexterAccountabilityQueryEngine.respond(
                queryKind: accountabilityQueryKind,
                snapshot: memoryStore.accountabilityTaskSnapshot(),
                legacyTaskDescription: memoryStore.activeTaskDescription,
                workflowSummary: memoryStore.workflowContext?.summary
            )
            demonstrationPhaseStore?.transition(to: .done, detail: "Accountability")
            await onTextChunk(accountabilityResponse)
            return DexterOrchestratorModelResponse(
                fullResponseText: accountabilityResponse,
                context: dexterContext,
                responseMode: .answer
            )
        }

        if let personalContextQueryKind = DexterPersonalContextIntentRecognizer.recognize(fromUserMessage: userTranscript),
           DexterAccountabilityIntentRecognizer.recognizeQuery(fromUserMessage: userTranscript) == nil {
            let authorizedPersonalContextInput = DexterAuthorizedPersonalContextInput.fromDexterContext(dexterContext)
            let personalContextGraph = DexterPersonalContextGraphBuilder.build(
                memoryStore: memoryStore,
                authorizedInput: authorizedPersonalContextInput
            )
            let personalContextResponse = DexterPersonalContextQueryEngine.respond(
                queryKind: personalContextQueryKind,
                graph: personalContextGraph,
                authorizedInput: authorizedPersonalContextInput
            )
            demonstrationPhaseStore?.transition(to: .done, detail: "Personal context")
            await onTextChunk(personalContextResponse)
            return DexterOrchestratorModelResponse(
                fullResponseText: personalContextResponse,
                context: dexterContext,
                responseMode: .answer
            )
        }

        demonstrationPhaseStore?.transition(to: .understanding, detail: "Understanding your request")

        let intentEngineResult = DexterPerformanceTiming.measureSync(bucket: .intent) {
            DexterIntentEngine.evaluate(userMessage: userTranscript, context: dexterContext)
        }
        lastIntentEngineResult = intentEngineResult

        let skillEngineResult = DexterSkillEngine.evaluate(
            userMessage: userTranscript,
            context: dexterContext,
            intentEngineResult: intentEngineResult
        )
        lastSkillEngineResult = skillEngineResult

        if intentEngineResult.requiresClarification,
           !DexterSkillEngine.shouldDeferIntentClarification(
               intentEngineResult: intentEngineResult,
               skillEngineResult: skillEngineResult
           ),
           let clarificationPrompt = intentEngineResult.clarificationPrompt {
            demonstrationPhaseStore?.transition(to: .done, detail: "Needs clarification")
            await onTextChunk(clarificationPrompt)
            return DexterOrchestratorModelResponse(
                fullResponseText: clarificationPrompt,
                context: dexterContext,
                responseMode: .answer
            )
        }

        let responseMode = DexterIntentResponseModeMapper.responseMode(for: intentEngineResult.structuredIntent)

        let teachingEngineResult = DexterTeachingEngine.evaluate(
            userMessage: userTranscript,
            contextPacket: contextPacket,
            structuredIntent: intentEngineResult.structuredIntent,
            sessionStore: teachingSessionStore
        )
        lastTeachingEngineResult = teachingEngineResult

        if let blockingTeachingMessage = teachingEngineResult.blockingUserMessage {
            demonstrationPhaseStore?.transition(to: .done, detail: "Waiting for step completion")
            await onTextChunk(blockingTeachingMessage)
            return DexterOrchestratorModelResponse(
                fullResponseText: blockingTeachingMessage,
                context: dexterContext,
                responseMode: teachingEngineResult.mapsToResponseMode
            )
        }

        let effectiveResponseMode = teachingEngineResult.isTeachingTurn
            ? teachingEngineResult.mapsToResponseMode
            : responseMode
        lastResponseMode = effectiveResponseMode

        if effectiveResponseMode == .act {
            DexterActionDiagnosticLog.action("intent detected")
            if !DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled {
                let unavailableMessage =
                    "Local computer control is currently unavailable. Dexter can still chat and explain your screen."
                demonstrationPhaseStore?.transition(to: .done, detail: unavailableMessage)
                await onTextChunk(unavailableMessage)
                return DexterOrchestratorModelResponse(
                    fullResponseText: unavailableMessage,
                    context: dexterContext,
                    responseMode: effectiveResponseMode
                )
            }

            if let actionResponse = await handleActionRequestIfNeeded(
                userTranscript: userTranscript,
                responseMode: effectiveResponseMode,
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
                responseMode: effectiveResponseMode
            )
        }

        if DexterObserveOnlyPolicy.isAutonomousComputerControlEnabled {
            if let learnedWorkflowResponse = await handleLearnedWorkflowIfNeeded(
                userTranscript: userTranscript,
                context: dexterContext,
                hasPersistedScreenContentGrant: options.hasPersistedScreenContentGrant,
                onTextChunk: onTextChunk
            ) {
                return learnedWorkflowResponse
            }

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
            responseMode: effectiveResponseMode,
            teachingMode: teachingEngineResult.isTeachingTurn ? teachingEngineResult.teachingMode : nil,
            context: dexterContext
        )
        relevancePlan = DexterSkillContextAdjuster.adjust(
            plan: relevancePlan,
            skill: skillEngineResult.matchedSkill,
            context: dexterContext
        )

        let contextPacketSummary = DexterTeachingPacketPromptBuilder.contextSummary(from: contextPacket)
        let teachingPromptSection: String?
        if teachingEngineResult.isTeachingTurn {
            teachingPromptSection = """
            mode: \(teachingEngineResult.teachingMode.rawValue)
            style: \(teachingEngineResult.teachingStyle.rawValue)
            \(contextPacketSummary)
            """
        } else {
            teachingPromptSection = nil
        }

        let availableToolsPromptSection = await toolRegistryGateway.modelToolsPromptSection()
        let skillPromptSection: String?
        if let matchedSkill = skillEngineResult.matchedSkill {
            skillPromptSection = DexterSkillPromptBuilder.promptSection(
                for: matchedSkill,
                mergedPlan: skillEngineResult.mergedIntentPlan
            )
        } else {
            skillPromptSection = nil
        }

        let structuredModelRequest = DexterStructuredModelRequestBuilder.build(
            dexterContext: dexterContext,
            relevancePlan: relevancePlan,
            availableToolsPromptSection: availableToolsPromptSection,
            teachingPromptSection: teachingPromptSection,
            skillPromptSection: skillPromptSection
        )

        let userRequestedScreenContext = options.usePointAtContextRelevancePlan
            || DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: userTranscript)

        let teachingInstructions: String
        if teachingEngineResult.isTeachingTurn {
            teachingInstructions = DexterTeachingModeInstructions.supplementalSystemInstructions(
                for: effectiveResponseMode,
                teachingMode: teachingEngineResult.teachingMode,
                teachingStyle: teachingEngineResult.teachingStyle,
                hasScreenContext: !structuredModelRequest.images.isEmpty,
                teachingSession: teachingSessionStore.activeSession,
                contextPacketSummary: contextPacketSummary
            )
        } else {
            teachingInstructions = DexterTeachingModeInstructions.supplementalSystemInstructions(
                for: effectiveResponseMode,
                hasScreenContext: !structuredModelRequest.images.isEmpty
            )
        }

        let honestyInstructions = DexterContextHonestyInstructions.supplementalSystemInstructions(
            userRequestedScreenContext: userRequestedScreenContext,
            screenCaptureAvailability: dexterContext.screen.captureAvailability,
            hasAttachedScreenshot: !structuredModelRequest.images.isEmpty
        )

        let personalizationHint = DexterPersonalizationService.explanationStyleHint(
            from: dexterContext.persistentMemory.retrievedMemories
        )

        let combinedSystemPrompt: String = [
            systemPrompt,
            teachingInstructions,
            honestyInstructions,
            personalizationHint ?? "",
            DexterExternalContentAuthorityPolicy.externalContentIsDataNotAuthorityInstruction
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        var preparedVisionPayload: DexterPreparedVisionPayload?
        var visionRequest: DexterVisionRequest?
        if !structuredModelRequest.images.isEmpty {
            preparedVisionPayload = await DexterVisionRequestPreparer.preparePayloadAsync(
                dexterContext: dexterContext,
                userMessage: userTranscript
            )
            if let preparedVisionPayload {
                visionRequest = DexterVisionRequestPreparer.buildVisionRequest(
                    structuredUserPrompt: structuredModelRequest.userPrompt,
                    dexterContext: dexterContext,
                    preparedPayload: preparedVisionPayload
                )
            }
        }

        let generationRequest = DexterModelGenerationRequest(
            systemPrompt: combinedSystemPrompt,
            userPrompt: structuredModelRequest.userPrompt,
            images: structuredModelRequest.images,
            conversationHistory: structuredModelRequest.conversationHistory,
            userRequestedScreenContext: userRequestedScreenContext,
            screenCaptureAvailability: dexterContext.screen.captureAvailability,
            preparedVisionPayload: preparedVisionPayload,
            visionRequest: visionRequest
        )

        let modelTimeoutSeconds: TimeInterval = generationRequest.images.isEmpty ? 120 : 90
        DexterTurnTrace.log("visualContextRequired=\(!generationRequest.images.isEmpty)")
        DexterTurnTrace.log("screenshot/images in request: \(generationRequest.images.count)")
        DexterDiagnosticLog.model("generation started (images: \(generationRequest.images.count))")
        DexterTurnTrace.log("awaiting model (timeout \(Int(modelTimeoutSeconds))s)")
        DexterTurnTrace.log("model request started")
        DexterPerformanceTiming.markModelGenerationStarted()
        let preferredCloudModelIdentifier = (modelProvider as? DexterModelGateway)?.preferredCloudModelIdentifier
            ?? modelProvider.modelIdentifier
        let modelRoutingContext = DexterModelGatewayRoutingContext.inferred(
            from: generationRequest,
            intentComplexity: intentEngineResult.complexity,
            userMessage: userTranscript,
            prefersLocalProcessingSetting: DexterModelGatewayPreferences.prefersLocalProcessing,
            preferredCloudModelIdentifier: preferredCloudModelIdentifier
        )

        let generationResult = try await DexterTaskTraceRecorder.shared.measure(bucket: .model) {
            try await DexterAsyncTimeout.withTimeout(seconds: modelTimeoutSeconds) { [self] in
                try await modelProvider.generateStreamingResponse(
                    request: generationRequest,
                    routingContext: modelRoutingContext,
                    onTextChunk: onTextChunk
                )
            }
        }
        DexterTurnTrace.log("model returned")
        DexterTurnTrace.log("model response received")
        DexterDiagnosticLog.model("generation finished")

        lastVisionResponse = generationResult.visionResponse

        if teachingEngineResult.isTeachingTurn,
           teachingEngineResult.teachingMode == .stepByStep
            || teachingEngineResult.teachingMode == .interactiveTutorial {
            let instructionSummary = String(generationResult.fullResponseText.prefix(280))
            DexterTeachingEngine.markInstructionDelivered(
                instructionSummary: instructionSummary,
                sessionStore: teachingSessionStore
            )
        }

        if executionStateMachineRegistry.latestSnapshot()?.currentPhase == .verifying
            || executionStateMachineRegistry.latestSnapshot()?.currentPhase == .executing {
            // UI stays on ACTING / VERIFYING until the execution state machine completes.
        } else {
            demonstrationPhaseStore?.transition(to: .done, detail: "Response ready")
        }

        return DexterOrchestratorModelResponse(
            fullResponseText: generationResult.fullResponseText,
            context: dexterContext,
            responseMode: effectiveResponseMode
        )
    }

    /// Permission-gated ACT step: PLAN → PERMISSION → EXECUTE → OBSERVE → VERIFY → REPORT.
    func executeVerifiedAction(
        proposedAction: DexterAction,
        context: DexterContext,
        hasPersistedScreenContentGrant: Bool = false,
        confirmationGrant: DexterActionConfirmationGrant? = nil,
        executionStateMachine: DexterExecutionStateMachine? = nil
    ) async -> DexterActionExecutionOutcome {
        let parentTaskIdentifier = taskStateStore.activeWorkflowTask?.id
            ?? taskStateStore.activeLearnedWorkflowRun?.id
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
            isComputerControlAuthorizedForSession: actionPermissionSettingsStore.isComputerControlAuthorizedForSession,
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
            confirmationGrant: confirmationGrant,
            demonstrationPhaseStore: demonstrationPhaseStore,
            executionStateMachine: executionStateMachine,
            executionStateMachineRegistry: executionStateMachineRegistry,
            parentTaskIdentifier: parentTaskIdentifier,
            actionRecoveryLedger: actionRecoveryLedger
        )
        lastTypedAction = outcome.action
        pendingActionExecution = outcome.pendingConfirmation
        lastExecutionSnapshot = outcome.executionSnapshot
        if let executionSnapshot = outcome.executionSnapshot {
            demonstrationPhaseStore?.applyExecutionSnapshot(executionSnapshot)
        }
        if let activityRecorder, let linkage = activityLinkageProvider?() {
            activityRecorder.recordActionExecutionOutcome(
                outcome: outcome,
                linkage: linkage,
                userRequest: context.userTranscript
            )
        }
        return outcome
    }

    private func handleActionUndoIfNeeded(
        userTranscript: String,
        dexterContext: DexterContext,
        hasPersistedScreenContentGrant: Bool,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async -> DexterOrchestratorModelResponse? {
        guard DexterActionRecoveryIntentRecognizer.recognizeUndo(fromUserMessage: userTranscript) else {
            return nil
        }

        guard let undoableEntry = actionRecoveryLedger.latestUndoableEntry(),
              let rollbackAction = DexterActionRecoveryEngine.rollbackAction(for: undoableEntry.metadata) else {
            let message = DexterActionRecoveryCopy.undoUnavailableMessage(for: actionRecoveryLedger.latestEntry()?.metadata)
            demonstrationPhaseStore?.transition(to: .done, detail: "Undo unavailable")
            await onTextChunk(message)
            return DexterOrchestratorModelResponse(
                fullResponseText: message,
                context: dexterContext,
                responseMode: .answer
            )
        }

        demonstrationPhaseStore?.transition(to: .planning, detail: "Undo last safe action")
        let planMessage = DexterActionRecoveryEngine.userFacingUndoPlan(entry: undoableEntry)
        await onTextChunk(planMessage)

        let outcome = await executeVerifiedAction(
            proposedAction: rollbackAction,
            context: dexterContext,
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
        )

        let combinedMessage = "\(planMessage) \(outcome.spokenSummary)"
        await onTextChunk(outcome.spokenSummary)
        return DexterOrchestratorModelResponse(
            fullResponseText: combinedMessage,
            context: dexterContext,
            responseMode: .guide
        )
    }

    private func handleWorkspaceIntentIfNeeded(
        userTranscript: String,
        dexterContext: DexterContext,
        contextPacket: DexterContextPacket,
        hasPersistedScreenContentGrant: Bool,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async -> DexterOrchestratorModelResponse? {
        let isSaveIntent = DexterWorkspaceIntentRecognizer.recognizeSave(fromUserMessage: userTranscript)
        let isRestoreIntent = DexterWorkspaceIntentRecognizer.recognizeRestore(fromUserMessage: userTranscript)
        guard isSaveIntent || isRestoreIntent else { return nil }

        let authorizedPersonalContextInput = DexterAuthorizedPersonalContextInput.fromDexterContextPacket(contextPacket)
        let personalContextGraph = DexterPersonalContextGraphBuilder.build(
            memoryStore: memoryStore,
            authorizedInput: authorizedPersonalContextInput
        )
        let accountabilitySnapshot = memoryStore.accountabilityTaskSnapshot()

        if isSaveIntent {
            let snapshot = DexterWorkspaceSnapshotCapture.capture(
                authorizedInput: authorizedPersonalContextInput,
                personalContextGraph: personalContextGraph,
                accountabilitySnapshot: accountabilitySnapshot
            )
            workspaceSnapshotStore.save(snapshot)
            let saveMessage = DexterWorkspaceSnapshotCapture.userFacingSaveSummary(snapshot: snapshot)
            demonstrationPhaseStore?.transition(to: .done, detail: "Workspace saved")
            await onTextChunk(saveMessage)
            return DexterOrchestratorModelResponse(
                fullResponseText: saveMessage,
                context: dexterContext,
                responseMode: .answer
            )
        }

        guard let desiredSnapshot = workspaceSnapshotStore.latestSnapshot() else {
            let message =
                "I do not have a saved workspace snapshot yet. Say “save my workspace” while your apps and task are set up the way you want."
            demonstrationPhaseStore?.transition(to: .done, detail: "No workspace snapshot")
            await onTextChunk(message)
            return DexterOrchestratorModelResponse(
                fullResponseText: message,
                context: dexterContext,
                responseMode: .answer
            )
        }

        demonstrationPhaseStore?.transition(to: .planning, detail: "Restoring workspace")

        let currentState = DexterWorkspaceCurrentState(
            authorizedInput: authorizedPersonalContextInput,
            personalContextGraph: personalContextGraph,
            accountabilitySnapshot: accountabilitySnapshot
        )

        let restoreResult = await DexterWorkspaceRestoreEngine.runRestore(
            desiredSnapshot: desiredSnapshot,
            currentState: currentState,
            memoryStore: memoryStore,
            executeVerifiedAction: { [self] proposedAction in
                await executeVerifiedAction(
                    proposedAction: proposedAction,
                    context: dexterContext,
                    hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
                )
            }
        )

        if restoreResult.stoppedAwaitingPermission {
            demonstrationPhaseStore?.transition(to: .waitingPermission, detail: "Workspace restore")
        } else {
            demonstrationPhaseStore?.transition(to: .done, detail: "Workspace restore")
        }

        await onTextChunk(restoreResult.userMessage)
        return DexterOrchestratorModelResponse(
            fullResponseText: restoreResult.userMessage,
            context: dexterContext,
            responseMode: .guide
        )
    }

    private func handleLearnedWorkflowIfNeeded(
        userTranscript: String,
        context: DexterContext,
        hasPersistedScreenContentGrant: Bool,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async -> DexterOrchestratorModelResponse? {
        let hasActiveLearnedWorkflow = taskStateStore.activeLearnedWorkflowRun?.isTerminal == false

        if !hasActiveLearnedWorkflow {
            if let matchedWorkflow = DexterWorkflowCatalog.workflowMatchingTrigger(userMessage: userTranscript) {
                taskStateStore.activeLearnedWorkflowRun = DexterWorkflowRunSession(
                    workflowIdentifier: matchedWorkflow.workflowIdentifier,
                    workflowName: matchedWorkflow.name
                )
            } else if let skillResult = lastSkillEngineResult,
                      let matchedSkill = skillResult.matchedSkill,
                      skillResult.matchConfidence >= 0.75,
                      let workflowIdentifier = matchedSkill.workflow.workflowIdentifier,
                      DexterWorkflowCatalog.workflow(forIdentifier: workflowIdentifier) != nil {
                taskStateStore.activeLearnedWorkflowRun = DexterWorkflowRunSession(
                    workflowIdentifier: workflowIdentifier,
                    workflowName: matchedSkill.name
                )
            }
        }

        guard let activeSession = taskStateStore.activeLearnedWorkflowRun,
              !activeSession.isTerminal,
              let workflow = DexterWorkflowCatalog.workflow(forIdentifier: activeSession.workflowIdentifier) else {
            if taskStateStore.activeLearnedWorkflowRun?.isTerminal == true {
                taskStateStore.activeLearnedWorkflowRun = nil
            }
            return nil
        }

        let workflowOutcome = await DexterWorkflowRuntimeEngine.processTurn(
            userMessage: userTranscript,
            workflow: workflow,
            session: activeSession,
            context: context,
            executeVerifiedAction: { proposedAction in
                await executeVerifiedAction(
                    proposedAction: proposedAction,
                    context: context,
                    hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
                )
            }
        )

        taskStateStore.activeLearnedWorkflowRun = workflowOutcome.session

        if workflowOutcome.session.isTerminal {
            taskStateStore.activeLearnedWorkflowRun = nil
        }

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

            let capabilityInput = await toolRegistryGateway.productCapabilityBuildInput()
            let productCapabilities = DexterProductCapabilityRegistry.buildCapabilities(input: capabilityInput)
            switch DexterActionCapabilityGate.evaluate(action: proposedAction, capabilities: productCapabilities) {
            case .allowed:
                break
            case .blocked(let userMessage):
                demonstrationPhaseStore?.transition(to: .done, detail: userMessage)
                await onTextChunk(userMessage)
                return DexterOrchestratorModelResponse(
                    fullResponseText: userMessage,
                    context: context,
                    responseMode: responseMode
                )
            }

            let executionStateMachine = DexterExecutionStateMachine(
                actionIdentifier: proposedAction.id,
                parentTaskIdentifier: taskStateStore.activeWorkflowTask?.id
            )
            executionStateMachineRegistry.register(executionStateMachine)
            do {
                try executionStateMachine.transition(
                    to: .understanding,
                    progressSummary: "Classified as a computer action request."
                )
                try executionStateMachine.transition(
                    to: .planning,
                    progressSummary: proposedAction.humanReadableDescription
                )
            } catch {
                DexterActionDiagnosticLog.action("execution state machine planning transition failed")
            }

            let outcome = await executeVerifiedAction(
                proposedAction: proposedAction,
                context: context,
                hasPersistedScreenContentGrant: hasPersistedScreenContentGrant,
                executionStateMachine: executionStateMachine
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

    private func applyMemoryBinding(from options: DexterModelGenerationOptions) {
        guard let defaultStore = memoryStore as? DefaultMemoryStore else { return }
        if let profileId = options.activeDexterProfileId,
           let workspaceId = options.activeFileWorkspaceId {
            defaultStore.currentMemoryBinding = .forWorkspace(profileId: profileId, fileWorkspaceId: workspaceId)
        } else if let profileId = options.activeDexterProfileId {
            defaultStore.currentMemoryBinding = .forDexterProfile(profileId)
        } else {
            defaultStore.currentMemoryBinding = .global
        }
    }
}

@MainActor
enum DexterOrchestratorFactory {
    static func makeDefault(
        ollamaProvider: OllamaProvider,
        demonstrationPhaseStore: DexterDemonstrationPhaseStore? = nil,
        demonstrationSessionStore: DexterDemonstrationSessionStore? = nil,
        fileWorkspaceStore: DexterFileWorkspaceStore? = nil
    ) -> DexterOrchestrator {
        let ollamaModelProvider = OllamaModelProviderAdapter(aiProvider: ollamaProvider)
        let claudeModelProvider: ClaudeModelProvider? = {
            guard DexterWorkerProxyClient.isWorkerBaseURLConfigured else { return nil }
            let proxyURL = "\(DexterWorkerProxyClient.workerBaseURL)/chat"
            return ClaudeModelProvider(claudeAPI: ClaudeAPI(proxyURL: proxyURL))
        }()
        let openAIModelProvider = OpenAIModelProvider()
        let modelProvider = DexterModelGateway(
            ollamaProvider: ollamaModelProvider,
            ollamaConnectionProvider: ollamaProvider,
            claudeProvider: claudeModelProvider,
            openAIProvider: openAIModelProvider
        )
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
            demonstrationSessionStore: demonstrationSessionStore ?? DexterDemonstrationSessionStore(),
            fileWorkspaceStore: fileWorkspaceStore
        )
    }
}
