//
//  DexterHubEventBridge.swift
//  leanring-buddy
//
//  Subscribes to DexterRuntimeUIStateStore and broadcasts Hub events over WebSocket.
//

import AppKit
import Combine
import Foundation

@MainActor
final class DexterHubEventBridge {
    private let webSocketServer = DexterHubWebSocketServer()
    private let pointerMomentCoordinator = DexterHubPointerMomentCoordinator()
    private let actionJourneyCoordinator = DexterHubActionJourneyCoordinator()
    private let teachingMomentCoordinator = DexterHubTeachingMomentCoordinator()
    private let workflowSuggestionCoordinator = DexterHubWorkflowSuggestionCoordinator()
    private var cancellables = Set<AnyCancellable>()
    private var contextPollTimer: Timer?
    private var lastPublishedFingerprint: String?
    private var lastObservedApplicationName: String?

    private var runtimeUIStateStore: DexterRuntimeUIStateStore?
    private var pendingConfirmationProvider: (() -> DexterActionConfirmationPresentation?)?
    private var accessibilityPermissionProvider: (() -> Bool)?
    private var memoryStoreProvider: (() -> MemoryStore?)?
    private var proactiveAutomationSettingsProvider: (() -> DexterProactiveAutomationSettingsStore?)?
    private var demoHealthSnapshotProvider: (() async -> [DexterHubDemoHealthCheck])?

    private(set) var isPointerMomentActive = false
    private var pointerMomentApplicationName: String?

    func install(
        runtimeUIStateStore: DexterRuntimeUIStateStore,
        pendingConfirmationProvider: @escaping () -> DexterActionConfirmationPresentation?,
        accessibilityPermissionProvider: @escaping () -> Bool,
        memoryStoreProvider: @escaping () -> MemoryStore,
        actionHistoryProvider: @escaping () -> DexterActionHistoryStore?,
        proactiveAutomationSettingsProvider: @escaping () -> DexterProactiveAutomationSettingsStore?,
        demoHealthSnapshotProvider: @escaping () async -> [DexterHubDemoHealthCheck],
        pointInvokeSessionPublisher: AnyPublisher<DexterPointInvokeSession?, Never>,
        voiceInteractionStatePublisher: AnyPublisher<DexterVoiceInteractionState, Never>,
        streamingResponseTextPublisher: AnyPublisher<String, Never>,
        teachingSessionPublisher: AnyPublisher<DexterTeachingSession?, Never>
    ) {
        guard self.runtimeUIStateStore == nil else { return }

        self.runtimeUIStateStore = runtimeUIStateStore
        self.pendingConfirmationProvider = pendingConfirmationProvider
        self.accessibilityPermissionProvider = accessibilityPermissionProvider
        self.memoryStoreProvider = memoryStoreProvider
        self.proactiveAutomationSettingsProvider = proactiveAutomationSettingsProvider
        self.demoHealthSnapshotProvider = demoHealthSnapshotProvider

        webSocketServer.inboundPayloadHandler = { [weak self] object in
            Task { @MainActor in
                self?.handleHubInboundPayload(object)
            }
        }

        webSocketServer.start(port: 8787)

        actionJourneyCoordinator.attach(eventBridge: self)

        pointerMomentCoordinator.install(
            eventBridge: self,
            pointInvokeSessionPublisher: pointInvokeSessionPublisher,
            voiceInteractionStatePublisher: voiceInteractionStatePublisher,
            streamingResponseTextPublisher: streamingResponseTextPublisher
        )

        DexterHubMemoryMomentReporter.register(eventBridge: self)
        DexterHubTeachingMomentReporter.register(eventBridge: self)
        teachingMomentCoordinator.install(teachingSessionPublisher: teachingSessionPublisher)
        workflowSuggestionCoordinator.install(
            eventBridge: self,
            actionHistoryProvider: actionHistoryProvider
        )

        Publishers.CombineLatest3(
            runtimeUIStateStore.$currentState,
            runtimeUIStateStore.$statusDetail,
            runtimeUIStateStore.$failurePresentation
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.publishRuntimeMappedEvent()
        }
        .store(in: &cancellables)

        startContextPolling()
        broadcastAmbientFocusIfNeeded()
        publishRuntimeMappedEvent()
    }

    func broadcastWatchingApplication(_ applicationName: String) {
        let payload = DexterHubWireEventBuilder.watching(applicationName: applicationName)
        broadcast(payload: payload, fingerprint: "watching|\(applicationName)")
    }

    private func broadcastAmbientFocusIfNeeded() {
        guard let proactiveAutomationSettingsProvider else { return }
        let registrations = proactiveAutomationSettingsProvider()?.automationRegistrations
            ?? DexterProactiveAutomationRegistry.defaultRegistrations()
        let focusMode = DexterHubAmbientFocusPolicy.isAmbientFocusMode(
            proactiveAutomationRegistrations: registrations
        )
        let payload = DexterHubWireEventBuilder.ambientFocus(focusMode: focusMode)
        broadcast(payload: payload, fingerprint: "ambientFocus|\(focusMode)")
    }

    func stop() {
        contextPollTimer?.invalidate()
        contextPollTimer = nil
        cancellables.removeAll()
        webSocketServer.stop()
        runtimeUIStateStore = nil
        isPointerMomentActive = false
        pointerMomentApplicationName = nil
    }

    func setPointerMomentActive(_ isActive: Bool, applicationName: String?) {
        isPointerMomentActive = isActive
        pointerMomentApplicationName = applicationName
        if !isActive {
            publishRuntimeMappedEvent()
        }
    }

    func broadcastPointerAware(
        applicationName: String,
        windowTitle: String?,
        targetSubtitle: String?
    ) {
        let payload = DexterHubWireEventBuilder.context(
            application: applicationName,
            windowTitle: windowTitle,
            title: "I see what you're looking at.",
            subtitle: targetSubtitle,
            interaction: "pointer"
        )
        let fingerprintTarget = targetSubtitle ?? ""
        broadcast(payload: payload, fingerprint: "pointer|aware|\(applicationName)|\(fingerprintTarget)")
        DexterHubEventBridgeLog.hubState("aware")
    }

    func broadcastPointerTargetUncertainty(targetLabel: String, applicationName: String?) {
        let title = "I think you're pointing at \(targetLabel). Is that right?"
        let payload = DexterHubWireEventBuilder.ambient(
            beat: "targetUncertain",
            hubState: "aware",
            title: title,
            subtitle: "Confirm on your Mac if that looks right.",
            application: applicationName,
            interaction: "pointer"
        )
        broadcast(payload: payload, fingerprint: "pointer|targetUncertain|\(targetLabel)")
        DexterHubEventBridgeLog.hubState("aware")
    }

    func broadcastPointerListening(applicationName: String?, targetSubtitle: String?) {
        let payload = DexterHubWireEventBuilder.state(
            hubState: "listening",
            title: "I'm listening...",
            subtitle: targetSubtitle ?? applicationName,
            application: applicationName,
            interaction: "pointer"
        )
        broadcast(payload: payload, fingerprint: "pointer|listening|\(targetSubtitle ?? "")")
        DexterHubEventBridgeLog.hubState("listening")
    }

    func broadcastPointerSpeaking(applicationName: String?, targetSubtitle: String?) {
        let payload = DexterHubWireEventBuilder.state(
            hubState: "speaking",
            title: DexterHubVoicePresentation.speakingTitle,
            subtitle: targetSubtitle ?? DexterHubVoicePresentation.pointerSpeakingSubtitle,
            application: applicationName,
            interaction: "pointer",
            voiceVisualOnly: true
        )
        broadcast(payload: payload, fingerprint: "pointer|speaking|\(targetSubtitle ?? "")")
        DexterHubEventBridgeLog.hubState("speaking")
    }

    func broadcastUnderstandingLook(applicationName: String?, targetSubtitle: String?) {
        let payload = DexterHubWireEventBuilder.ambient(
            beat: "understandingLook",
            hubState: "thinking",
            title: "Let me look.",
            subtitle: targetSubtitle ?? applicationName,
            application: applicationName,
            interaction: "pointer"
        )
        broadcast(payload: payload, fingerprint: "pointer|understandingLook|\(targetSubtitle ?? "")")
        DexterHubEventBridgeLog.hubState("thinking")
    }

    func broadcastUnderstandingGotIt(applicationName: String?, targetSubtitle: String?) {
        let payload = DexterHubWireEventBuilder.ambient(
            beat: "understandingGotIt",
            hubState: "thinking",
            title: "Got it.",
            subtitle: targetSubtitle ?? applicationName,
            application: applicationName,
            interaction: "pointer"
        )
        broadcast(payload: payload, fingerprint: "pointer|understandingGotIt|\(targetSubtitle ?? "")")
        DexterHubEventBridgeLog.hubState("thinking")
    }

    func broadcastAnswerSummary(title: String, subtitle: String, applicationName: String?) {
        let payload = DexterHubWireEventBuilder.ambient(
            beat: "answer",
            hubState: "aware",
            title: title,
            subtitle: subtitle,
            application: applicationName,
            interaction: "pointer"
        )
        broadcast(payload: payload, fingerprint: "pointer|answer|\(title)|\(subtitle)")
        DexterHubEventBridgeLog.hubState("answer")
    }

    func broadcastMemorySave(summary: String, memoryRecordId: String?) {
        let payload = DexterHubWireEventBuilder.memory(
            phase: "remembering",
            title: "I'll remember that.",
            subtitle: summary,
            memoryRecordId: memoryRecordId,
            memoryActionsSupported: memoryRecordId != nil
        )
        broadcast(payload: payload, fingerprint: "memory|save|\(summary)|\(memoryRecordId ?? "")")
        DexterHubEventBridgeLog.info("memory=SAVE")
    }

    func broadcastMemoryRecall(summary: String, memoryRecordId: String?, preferenceReflection: String? = nil) {
        let payload = DexterHubWireEventBuilder.memory(
            phase: "recalled",
            title: "I remembered.",
            subtitle: summary,
            memoryRecordId: memoryRecordId,
            memoryActionsSupported: false,
            preferenceReflection: preferenceReflection
        )
        broadcast(payload: payload, fingerprint: "memory|recall|\(summary)|\(preferenceReflection ?? "")")
        DexterHubEventBridgeLog.info("memory=RECALL")
    }

    func broadcastProjectContext(label: String, projectName: String) {
        let payload = DexterHubWireEventBuilder.projectContext(label: label, projectName: projectName)
        broadcast(payload: payload, fingerprint: "projectContext|\(label)|\(projectName)")
        DexterHubEventBridgeLog.info("projectContext=\(projectName)")
    }

    func broadcastWorkflowSuggestion(
        routineDisplayName: String,
        patternSummary: String,
        trustPreview: String,
        routineRunSupported: Bool,
        catalogWorkflowIdentifier: String?
    ) {
        let payload = DexterHubWireEventBuilder.workflowSuggestion(
            phase: "suggest",
            title: "I noticed you do this a lot.",
            subtitle: "Want me to turn it into a routine?",
            routineDisplayName: routineDisplayName,
            trustPreview: trustPreview,
            routineRunSupported: routineRunSupported && catalogWorkflowIdentifier != nil,
            catalogWorkflowIdentifier: catalogWorkflowIdentifier
        )
        let fingerprint = "workflow|suggest|\(routineDisplayName)|\(catalogWorkflowIdentifier ?? "")"
        broadcast(payload: payload, fingerprint: fingerprint)
        DexterHubEventBridgeLog.info("workflow=SUGGEST \(routineDisplayName)")
    }

    func broadcastWorkflowRoutinePreview(routineDisplayName: String, trustPreview: String) {
        let payload = DexterHubWireEventBuilder.workflowSuggestion(
            phase: "preview",
            title: "I noticed something.",
            subtitle: routineDisplayName,
            routineDisplayName: routineDisplayName,
            trustPreview: trustPreview,
            routineRunSupported: false,
            catalogWorkflowIdentifier: nil
        )
        broadcast(payload: payload, fingerprint: "workflow|preview|\(routineDisplayName)")
    }

    func broadcastWorkflowSuggestionDismissed() {
        let payload = DexterHubWireEventBuilder.workflowSuggestion(
            phase: "none",
            title: "",
            subtitle: nil,
            routineDisplayName: nil,
            trustPreview: nil,
            routineRunSupported: nil,
            catalogWorkflowIdentifier: nil
        )
        broadcast(payload: payload, fingerprint: "workflow|none")
    }

    private func handleHubInboundPayload(_ object: [String: Any]) {
        DexterHubMemoryActionHandler.handleInboundPayload(object, memoryStore: memoryStoreProvider?())

        if object["type"] as? String == "workflowSuggestionResponse",
           let response = object["response"] as? String {
            let catalogWorkflowIdentifier = object["catalogWorkflowIdentifier"] as? String
            workflowSuggestionCoordinator.handleHubResponse(
                response,
                catalogWorkflowIdentifier: catalogWorkflowIdentifier
            )
            return
        }

        if object["type"] as? String == "teachingStyle",
           let styleIdentifier = object["style"] as? String {
            DexterHubTeachingStylePreferenceStore.applyHubStyleIdentifier(styleIdentifier)
            DexterHubEventBridgeLog.info("teachingStyle=\(styleIdentifier) (applies to next teaching turn)")
            return
        }

        if object["type"] as? String == "requestDemoHealth" {
            Task { @MainActor in
                await self.broadcastDemoHealthSnapshot()
            }
            return
        }

        if object["type"] as? String == "command" {
            DexterHubEventBridgeLog.info("command received (presentation-only — approve on Mac)")
        }
    }

    private func broadcastDemoHealthSnapshot() async {
        guard let demoHealthSnapshotProvider else { return }
        let checks = await demoHealthSnapshotProvider()
        let wireChecks = checks.map { check in
            ["id": check.identifier, "status": check.status]
        }
        let payload = DexterHubWireEventBuilder.demoHealth(checks: wireChecks)
        webSocketServer.broadcast(data: payload)
        DexterHubEventBridgeLog.info("demoHealth broadcast (\(checks.count) checks)")
    }

    func broadcastTeachingMoment(
        phase: String,
        title: String,
        subtitle: String?,
        teachingStyle: String?,
        stepIndex: Int?,
        stepSummary: String?,
        stepPreviews: [DexterHubTeachingStepPreview]?
    ) {
        let wirePreviews = stepPreviews?.map { preview in
            ["index": preview.index, "label": preview.label] as [String: Any]
        }
        let payload = DexterHubWireEventBuilder.teaching(
            phase: phase,
            title: title,
            subtitle: subtitle,
            teachingStyle: teachingStyle,
            stepIndex: stepIndex,
            stepSummary: stepSummary,
            stepPreviews: wirePreviews
        )
        let fingerprint = "teaching|\(phase)|\(title)|\(subtitle ?? "")|\(stepIndex ?? 0)"
        broadcast(payload: payload, fingerprint: fingerprint)
        DexterHubEventBridgeLog.info("teaching=\(phase.uppercased())")
    }

    func broadcastTeachingCleared() {
        let payload = DexterHubWireEventBuilder.teachingCleared()
        broadcast(payload: payload, fingerprint: "teaching|cleared")
        DexterHubEventBridgeLog.info("teaching=CLEARED")
    }

    private func publishRuntimeMappedEvent() {
        guard let runtimeUIStateStore else { return }
        let runtimeUIState = runtimeUIStateStore.currentState

        if isPointerMomentActive {
            switch runtimeUIState {
            case .understanding, .thinking, .planning:
                return
            case .idle:
                if runtimeUIStateStore.activeExecutionSnapshot == nil {
                    return
                }
            default:
                break
            }
        }

        let input = DexterHubEventMapper.Input(
            runtimeUIState: runtimeUIState,
            statusDetail: runtimeUIStateStore.statusDetail,
            executionSnapshot: runtimeUIStateStore.activeExecutionSnapshot,
            failurePresentation: runtimeUIStateStore.failurePresentation,
            pendingConfirmation: pendingConfirmationProvider?(),
            isPointerMomentActive: isPointerMomentActive,
            voiceInteractionState: runtimeUIStateStore.currentVoiceInteractionState
        )

        let mapped = DexterHubEventMapper.map(input)
        actionJourneyCoordinator.resetForNewExecution(
            runtimeUIStateStore.activeExecutionSnapshot?.executionIdentifier
        )
        actionJourneyCoordinator.publishMappedEvent(mapped) { [weak self] eventToPublish in
            self?.publish(eventToPublish)
            self?.evaluateWorkflowSuggestionIfAppropriate(
                mapped: eventToPublish,
                runtimeUIState: runtimeUIState
            )
        }
    }

    private func evaluateWorkflowSuggestionIfAppropriate(
        mapped: DexterHubEventMapper.MappedEvent,
        runtimeUIState: DexterRuntimeUIState
    ) {
        guard runtimeUIState == .done || runtimeUIState == .idle else { return }
        guard case .state(let hubState, _, _, _, _, _, let verificationOutcome) = mapped else { return }
        guard hubState == "success", verificationOutcome == "verified" else { return }
        let registrations = proactiveAutomationSettingsProvider?()?.automationRegistrations
            ?? DexterProactiveAutomationRegistry.defaultRegistrations()
        let isAmbientFocusMode = DexterHubAmbientFocusPolicy.isAmbientFocusMode(
            proactiveAutomationRegistrations: registrations
        )
        workflowSuggestionCoordinator.evaluateAfterVerifiedCompletionIfIdle(
            isAmbientFocusMode: isAmbientFocusMode
        )
    }

    func broadcastActionProposalCanDo(actionDescription: String) {
        let payload = DexterHubWireEventBuilder.ambient(
            beat: "actionCanDo",
            hubState: "thinking",
            title: "I can do that.",
            subtitle: actionDescription,
            application: nil,
            interaction: "default"
        )
        broadcast(payload: payload, fingerprint: "action|canDo|\(actionDescription)")
        DexterHubEventBridgeLog.hubState("thinking")
    }

    func broadcastActionProposalWantMeTo(actionDescription: String) {
        let payload = DexterHubWireEventBuilder.ambient(
            beat: "actionWantMeTo",
            hubState: "thinking",
            title: "Want me to?",
            subtitle: actionDescription,
            application: nil,
            interaction: "default"
        )
        broadcast(payload: payload, fingerprint: "action|wantMeTo|\(actionDescription)")
        DexterHubEventBridgeLog.hubState("thinking")
    }

    private func publish(_ mapped: DexterHubEventMapper.MappedEvent) {
        switch mapped {
        case .none:
            return
        case .state(
            let hubState,
            let title,
            let subtitle,
            let application,
            let journeySteps,
            let retrySupported,
            let verificationOutcome
        ):
            let interaction = isPointerMomentActive ? "pointer" : nil
            let payload = DexterHubWireEventBuilder.state(
                hubState: hubState,
                title: title,
                subtitle: subtitle,
                application: application,
                interaction: interaction,
                journeySteps: Self.wireJourneySteps(journeySteps),
                retrySupported: retrySupported,
                verificationOutcome: verificationOutcome,
                voiceVisualOnly: hubState == "speaking" ? true : nil
            )
            let journeyFingerprint = journeySteps?.map { "\($0.label):\($0.status)" }.joined(separator: ",") ?? ""
            publishIfChanged(
                fingerprint: "state|\(hubState)|\(title)|\(subtitle ?? "")|\(journeyFingerprint)|\(verificationOutcome ?? "")",
                payload: payload
            )
            DexterHubEventBridgeLog.hubState(hubState)
        case .context(let application, let windowTitle, let title):
            let payload = DexterHubWireEventBuilder.context(
                application: application,
                windowTitle: windowTitle,
                title: title
            )
            publishIfChanged(fingerprint: "context|\(application)|\(windowTitle ?? "")", payload: payload)
            DexterHubEventBridgeLog.hubState("aware")
        case .permission(let title, let subtitle, let actionIdentifier, let actionDescription):
            let interaction = isPointerMomentActive ? "pointer" : nil
            let journeySteps = DexterHubJourneySupport.journeySteps(for: .waitingPermission)
            let payload = DexterHubWireEventBuilder.permission(
                title: title,
                subtitle: subtitle,
                actionIdentifier: actionIdentifier,
                actionDescription: actionDescription,
                interaction: interaction,
                journeySteps: Self.wireJourneySteps(journeySteps)
            )
            publishIfChanged(
                fingerprint: "permission|\(actionIdentifier)|\(subtitle)|\(interaction ?? "")",
                payload: payload
            )
            DexterHubEventBridgeLog.hubState("permission")
        }
    }

    private func broadcast(payload: Data, fingerprint: String) {
        lastPublishedFingerprint = fingerprint
        webSocketServer.broadcast(data: payload)
    }

    private func publishIfChanged(fingerprint: String, payload: Data) {
        guard lastPublishedFingerprint != fingerprint else { return }
        lastPublishedFingerprint = fingerprint
        webSocketServer.broadcast(data: payload)
    }

    private func startContextPolling() {
        contextPollTimer?.invalidate()
        contextPollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollActiveApplicationContextIfIdle()
            }
        }
    }

    private func pollActiveApplicationContextIfIdle() {
        guard let runtimeUIStateStore else { return }
        guard !isPointerMomentActive else { return }
        guard runtimeUIStateStore.currentState == .idle || runtimeUIStateStore.currentState == .cancelled else {
            return
        }
        guard accessibilityPermissionProvider?() == true else { return }

        let pointerLocation = NSEvent.mouseLocation
        let environment = DexterEnvironmentContextCollector.collect(
            hasAccessibilityPermission: true,
            pointerLocationInScreenSpace: pointerLocation
        )
        guard environment.activeApplication.availability == .available,
              let applicationName = environment.activeApplication.localizedName?.nonEmptyTrimmedValue
        else {
            return
        }

        guard applicationName != lastObservedApplicationName else { return }
        lastObservedApplicationName = applicationName

        broadcastWatchingApplication(applicationName)
        broadcastAmbientFocusIfNeeded()
    }

    private static func wireJourneySteps(_ steps: [DexterHubJourneyStep]?) -> [[String: String]]? {
        guard let steps, !steps.isEmpty else { return nil }
        return steps.map { step in
            ["label": step.label, "status": step.status]
        }
    }
}
