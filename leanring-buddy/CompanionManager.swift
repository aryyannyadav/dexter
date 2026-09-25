//
//  CompanionManager.swift
//  leanring-buddy
//
//  Central state manager for the companion voice mode. Owns the push-to-talk
//  pipeline (dictation manager + global shortcut monitor + overlay) and
//  exposes observable voice state for the panel UI.
//

import AVFoundation
import Combine
import CoreGraphics
import Foundation
import PostHog
import ScreenCaptureKit
import SwiftUI

@MainActor
final class CompanionManager: ObservableObject {
    let dexterVoiceCoordinator = DexterVoiceCoordinator()

    var voiceInteractionState: DexterVoiceInteractionState {
        dexterVoiceCoordinator.interactionState
    }

    /// Microphone button UI only — not coupled to chat “thinking” or screen context.
    var microphoneButtonInteractionState: DexterVoiceInteractionState {
        switch microphoneRuntimeState {
        case .listening:
            return .listening
        case .starting:
            return .thinking
        case .processing:
            return .transcribing
        case .idle, .error:
            return .idle
        }
    }

    var microphoneButtonShowsError: Bool {
        if microphonePermissionState == .denied || microphonePermissionState == .unavailable {
            return true
        }
        guard microphoneRuntimeState == .error else { return false }
        guard let microphoneInputErrorMessage, !microphoneInputErrorMessage.isEmpty else { return false }
        let normalizedMessage = microphoneInputErrorMessage.lowercased()
        if normalizedMessage.contains("cancelled") || normalizedMessage.contains("canceled") {
            return false
        }
        return true
    }
    @Published private(set) var lastTranscript: String?
    @Published private(set) var currentAudioPowerLevel: CGFloat = 0
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var microphonePermissionState: DexterMicrophonePermissionState = .notDetermined
    @Published private(set) var microphoneRuntimeState: DexterMicrophoneRuntimeState = .idle
    @Published private(set) var microphoneInputErrorMessage: String?
    @Published private(set) var screenPermissionState: DexterScreenPermissionState = .unknown
    @Published private(set) var hasScreenContentPermission = false

    /// Screen location (global AppKit coords) of a detected UI element the
    /// buddy should fly to and point at. Parsed from Claude's response;
    /// observed by BlueCursorView to trigger the flight animation.
    @Published var detectedElementScreenLocation: CGPoint?
    /// The display frame (global AppKit coords) of the screen the detected
    /// element is on, so BlueCursorView knows which screen overlay should animate.
    @Published var detectedElementDisplayFrame: CGRect?
    /// Custom speech bubble text for the pointing animation. When set,
    /// BlueCursorView uses this instead of a random pointer phrase.
    @Published var detectedElementBubbleText: String?

    // MARK: - Onboarding Video State (shared across all screen overlays)

    @Published var onboardingVideoPlayer: AVPlayer?
    @Published var showOnboardingVideo: Bool = false
    @Published var onboardingVideoOpacity: Double = 0.0
    private var onboardingVideoEndObserver: NSObjectProtocol?
    private var onboardingDemoTimeObserver: Any?

    // MARK: - Onboarding Prompt Bubble

    /// Text streamed character-by-character on the cursor after the onboarding video ends.
    @Published var onboardingPromptText: String = ""
    @Published var onboardingPromptOpacity: Double = 0.0
    @Published var showOnboardingPrompt: Bool = false

    // MARK: - Onboarding Music

    private var onboardingMusicPlayer: AVAudioPlayer?
    private var onboardingMusicFadeTimer: Timer?

    let buddyDictationManager = BuddyDictationManager()
    let globalPushToTalkShortcutMonitor = GlobalPushToTalkShortcutMonitor()
    private let globalHomeShortcutMonitor = DexterGlobalHomeShortcutMonitor()
    let overlayWindowManager = OverlayWindowManager()
    private var lastAgentLifecycleAnnouncementState: DexterRuntimeUIState?
    // Response text is now displayed inline on the cursor overlay via
    // streamingResponseText, so no separate response overlay manager is needed.

    /// Base URL for the Cloudflare Worker proxy. All API requests route
    /// through this so keys never ship in the app binary.
    private static var workerBaseURL: String {
        DexterWorkerProxyClient.workerBaseURL
    }

    let dexterRuntimeUIStateStore = DexterRuntimeUIStateStore()
    let dexterAvatarPresence = DexterAvatarPresenceModel()

    var activeCharacterState: DexterCharacterState {
        dexterAvatarPresence.characterState
    }

    var isAssistantAudioSpeaking: Bool {
        dexterSpokenResponseService.isSpeaking
    }
    let dexterTeachingOverlayStore = DexterTeachingOverlayStore()
    let dexterSuggestionStore = DexterSuggestionStore()
    @Published private(set) var dexterProductCapabilities: [DexterProductCapability] = []
    let dexterProfileStore = DexterProfileStore()
    let dexterFileWorkspaceStore: DexterFileWorkspaceStore
    lazy var dexterFileWorkspaceService = DexterFileWorkspaceService(store: dexterFileWorkspaceStore)
    let universalCommandPanelManager = DexterUniversalCommandPanelManager()

    init() {
        dexterFileWorkspaceStore = DexterFileWorkspaceStore()
        dexterRoutineStore = DexterRoutineStore()
        dexterFileWorkspaceStore.activityRecorder = dexterActivityRecorder
        dexterRoutineStore.activityRecorder = dexterActivityRecorder
        activityRecorderChangeCancellable = dexterActivityRecorder.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    @Published var pendingUniversalCommandProfileId: UUID?
    @Published var pendingUniversalCommandRoutineId: UUID?
    @Published var pendingUniversalCommandComposerText: String?
    @Published var shouldFocusHomeComposerAfterOnboarding = false
    @Published var pendingOnboardingComposerPlaceholder: String?
    @Published var pendingOnboardingFirstSuggestionPrompt: String?
    @Published var shouldPresentRoutinesList = false
    let dexterActivityRecorder = DexterActivityRecorder()
    let dexterRoutineStore: DexterRoutineStore
    let dexterProfileWorkSuggestionStore = DexterProfileWorkSuggestionStore()
    let dexterAgentHUDController = DexterAgentHUDController()
    let interactiveOnboardingStore = DexterInteractiveOnboardingStore()
    let firstRunOnboardingStore = DexterFirstRunOnboardingStore()

    var dexterDemonstrationPhaseStore: DexterRuntimeUIStateStore {
        dexterRuntimeUIStateStore
    }

    private let dexterDemonstrationSessionStore = DexterDemonstrationSessionStore()

    let ollamaAIProvider = OllamaProvider()

    var dexterAIProvider: AIProvider {
        ollamaAIProvider
    }

    private lazy var dexterOrchestrator: DexterOrchestrator = {
        let orchestrator = DexterOrchestratorFactory.makeDefault(
            ollamaProvider: ollamaAIProvider,
            demonstrationPhaseStore: dexterRuntimeUIStateStore,
            demonstrationSessionStore: dexterDemonstrationSessionStore,
            fileWorkspaceStore: dexterFileWorkspaceStore
        )
        wireDexterActivityRecording(orchestrator: orchestrator)
        return orchestrator
    }()

    @Published var isDexterActivityBrowserPresented = false
    @Published var dexterActivityBrowserProfileId: UUID?

    private func wireDexterActivityRecording(orchestrator: DexterOrchestrator) {
        orchestrator.activityRecorder = dexterActivityRecorder
        orchestrator.activityLinkageProvider = { [weak self] in
            guard let self else {
                return DexterActivityLinkage(dexterProfileId: nil, conversationId: nil, fileWorkspaceId: nil)
            }
            let workspaceId = self.dexterProfileStore.activeProfileId.flatMap {
                self.dexterFileWorkspaceStore.workspace(forProfileId: $0)?.id
            }
            return DexterActivityLinkage(
                dexterProfileId: self.dexterProfileStore.activeProfileId,
                conversationId: self.activeHomeConversationIdentifier,
                fileWorkspaceId: workspaceId
            )
        }
        if let defaultMemoryStore = orchestrator.memoryStore as? DefaultMemoryStore {
            defaultMemoryStore.activityRecorder = dexterActivityRecorder
        }
        dexterRoutineStore.activityRecorder = dexterActivityRecorder
        dexterFileWorkspaceStore.activityRecorder = dexterActivityRecorder
    }

    func presentDexterActivityBrowser(profileId: UUID?) {
        dexterActivityBrowserProfileId = profileId
        isDexterActivityBrowserPresented = true
    }

    private lazy var elevenLabsTTSClient: ElevenLabsTTSClient = {
        return ElevenLabsTTSClient(proxyURL: "\(Self.workerBaseURL)/tts")
    }()

    private lazy var dexterSpokenResponseService: DexterSpokenResponseService = {
        DexterSpokenResponseService(
            elevenLabsTTSClient: elevenLabsTTSClient,
            voiceSettingsStore: dexterVoiceCoordinator.settingsStore
        )
    }()

    /// The currently running AI response task, if any. Cancelled when the user
    /// speaks again so a new response can begin immediately.
    private let userTurnController = DexterUserTurnController()
    private var activePushToTalkSessionIdentifier: UUID?

    private var shortcutTransitionCancellable: AnyCancellable?
    private var pointInvokeShortcutCancellable: AnyCancellable?
    private var voiceCoordinatorForwardCancellable: AnyCancellable?
    private var demonstrationPhaseForwardCancellable: AnyCancellable?
    private var audioPowerCancellable: AnyCancellable?
    private var accessibilityCheckTimer: Timer?
    private var pendingKeyboardShortcutStartTask: Task<Void, Never>?
    private var pendingActionApprovalTask: Task<Void, Never>?
    /// Scheduled hide for transient cursor mode — cancelled if the user
    /// speaks again before the delay elapses.
    private var transientHideTask: Task<Void, Never>?
    private var interactiveOnboardingFinaleCompletionScheduled = false
    private var activityRecorderChangeCancellable: AnyCancellable?
    private var deferredLaunchWarmupTask: Task<Void, Never>?

    /// True when all three required permissions (accessibility, screen recording,
    /// microphone) are granted. Used by the panel to show a single "all good" state.
    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission && hasMicrophonePermission && hasScreenContentPermission
    }

    /// Whether the blue cursor overlay is currently visible on screen.
    /// Used by the panel to show accurate status text ("Active" vs "Ready").
    @Published private(set) var isOverlayVisible: Bool = false

    @Published private(set) var actionConfirmationPresentation: DexterActionConfirmationPresentation?

    @Published private(set) var dexterPersistentMemoryEntries: [DexterMemoryEntry] = []
    @Published private(set) var pendingMemoryInferenceSuggestion: DexterMemoryInferenceSuggestion?
    @Published private(set) var dexterSessionExchangeCount: Int = 0
    @Published private(set) var dexterActiveTaskDescription: String?
    @Published private(set) var dexterWorkflowContextSummary: String?
    @Published private(set) var panelLastActionSummary: String?

    @Published private(set) var dexterChatMessages: [DexterChatMessage] = []
    @Published private(set) var dexterRecentConversations: [DexterRecentConversationSummary] = []
    /// When set, the active thread is a persisted recent conversation (archived JSON on disk).
    @Published private(set) var activeHomeConversationIdentifier: UUID?
    @Published var homeWorkspacePresentation: DexterHomeWorkspacePresentation = .dashboard
    @Published private(set) var dexterChatErrorMessage: String?
    @Published private(set) var dexterSpokenResponseErrorMessage: String?
    @Published private(set) var voiceInputErrorPresentation: DexterVoiceInputErrorPresentation?
    var pendingMainWindowDestination: DexterMainWindowDestination = .chat

    let openClawGatewayHealthMonitor = OpenClawGatewayHealthMonitor.shared
    lazy var dexterIntegrationService = DexterIntegrationService(healthMonitor: openClawGatewayHealthMonitor)

    var openClawGatewayStatusLine: String {
        openClawGatewayHealthMonitor.statusLine
    }

    @Published private(set) var hasVerifiedScreenCaptureProbe = false
    @Published private(set) var microphoneHardwareInputDetected = false

    var isDexterScreenContextAvailable: Bool {
        hasScreenRecordingPermission && hasVerifiedScreenCaptureProbe
    }

    @Published private(set) var dexterScreenContextUIState: DexterScreenContextUIState = .unavailable
    @Published private(set) var lastDexterContextSnapshot: DexterContextSnapshot?

    @Published private(set) var activePointInvokeSession: DexterPointInvokeSession?
    @Published private(set) var isPreparingPointInvokeSession = false

    func clearActivePointInvokeSession() {
        activePointInvokeSession = nil
        dexterTeachingOverlayStore.dismiss(reason: "point_invoke_cleared")
    }

    var pointAskPresenceState: DexterPointAskPresenceState {
        DexterPointAskPresenceState.resolve(
            activePointInvokeSession: activePointInvokeSession,
            isPreparingPointInvokeSession: isPreparingPointInvokeSession,
            voiceInteractionState: dexterVoiceCoordinator.interactionState
        )
    }

    func refreshDexterScreenContextUIState(logScreenPermissionDiagnostics: Bool = false) {
        let screenPreflightGranted = CGPreflightScreenCaptureAccess()
        if logScreenPermissionDiagnostics {
            DexterPermissionDiagnostics.logScreenRecordingPreflight(screenPreflightGranted)
        }

        if !screenPreflightGranted {
            dexterScreenContextUIState = .permissionRequired
            return
        }

        if hasVerifiedScreenCaptureProbe {
            dexterScreenContextUIState = .ready
        } else {
            dexterScreenContextUIState = .unavailable
        }
    }

    private var isScreenCaptureCapabilityProbeInFlight = false

    /// One-shot Screen Recording verification. Not called from permission polling.
    func runScreenCaptureCapabilityProbeIfNeeded() {
        guard !isScreenCaptureCapabilityProbeInFlight else { return }
        guard CGPreflightScreenCaptureAccess() else {
            hasVerifiedScreenCaptureProbe = false
            refreshDexterScreenContextUIState()
            return
        }
        if hasVerifiedScreenCaptureProbe {
            refreshDexterScreenContextUIState()
            return
        }

        isScreenCaptureCapabilityProbeInFlight = true
        Task {
            let probeSucceeded = await DexterScreenCapturePermissionProbe.captureTestFrameSucceeded()
            hasVerifiedScreenCaptureProbe = probeSucceeded
            isScreenCaptureCapabilityProbeInFlight = false
            refreshDexterScreenContextUIState()
        }
    }

    var preferredMacSpeechVoiceIdentifier: String? {
        get { dexterVoiceCoordinator.voiceSettings.preferredMacSpeechVoiceIdentifier }
        set {
            var updatedSettings = dexterVoiceCoordinator.voiceSettings
            updatedSettings.preferredMacSpeechVoiceIdentifier = newValue
            dexterVoiceCoordinator.voiceSettings = updatedSettings
        }
    }

    var selectedModelDisplayName: String {
        ollamaAIProvider.configuredModelName
    }

    func testOllamaConnection() {
        Task {
            await ollamaAIProvider.testConnection()
        }
    }

    func refreshOllamaConnectionStatus() {
        Task {
            await ollamaAIProvider.refreshConnectionStatus()
        }
    }

    func refreshOpenClawGatewayConnection() {
        Task {
            await openClawGatewayHealthMonitor.refreshHealthIfNeeded(force: true)
            refreshDexterIntegrations()
        }
    }

    func refreshDexterIntegrations() {
        let integrationContext = DexterIntegrationContext(
            activeApplicationName: lastDexterContextSnapshot?.activeApplicationName,
            browserPageURL: lastDexterContextSnapshot?.browserURL,
            browserPageTitle: lastDexterContextSnapshot?.browserPageTitle
        )
        Task {
            await dexterIntegrationService.refreshIntegrations(context: integrationContext)
            refreshDexterProductCapabilities()
        }
    }

    func refreshDexterProductCapabilities() {
        let input = DexterProductCapabilityBuildInput(
            discoveryReport: openClawGatewayHealthMonitor.capabilityDiscoveryReport,
            gatewayConnected: openClawGatewayHealthMonitor.connectionState.isConnected,
            hasAccessibilityPermission: hasAccessibilityPermission,
            hasScreenRecordingPermission: hasScreenRecordingPermission,
            hasMicrophonePermission: hasMicrophonePermission,
            hasScreenContentPermission: hasScreenContentPermission,
            integrations: dexterIntegrationService.integrations
        )
        dexterProductCapabilities = DexterProductCapabilityRegistry.buildCapabilities(input: input)
    }

    var panelLastTypedAction: DexterAction? {
        dexterOrchestrator.lastTypedAction
    }

    var panelActiveWorkflowTask: DexterTask? {
        dexterOrchestrator.taskStateStore.activeWorkflowTask
    }

    var autoApproveLowRiskActions: Bool {
        get { dexterOrchestrator.actionPermissionSettings.autoApproveLowRiskActions }
        set {
            var updatedSettings = dexterOrchestrator.actionPermissionSettings
            updatedSettings.autoApproveLowRiskActions = newValue
            dexterOrchestrator.actionPermissionSettings = updatedSettings
        }
    }

    func dexterExplicitlyEnabledProactiveAutomations() -> [DexterProactiveAutomationRegistration] {
        dexterOrchestrator.proactiveAutomationSettingsStore.automationRegistrations
            .filter(\.isExplicitlyEnabledByUser)
    }

    private var runningDexterRoutineIDs = Set<UUID>()

    func evaluateDueDexterRoutines() {
        DexterRoutineDueRoutineCoordinator.evaluateDueRoutines(companionManager: self)
    }

    func installUniversalCommand(settingsRouter: DexterSettingsRouter) {
        universalCommandPanelManager.install(companionManager: self, settingsRouter: settingsRouter)
    }

    func universalCommandSearchContext() -> DexterUniversalCommandSearchContext {
        let activeProfileId = dexterProfileStore.activeProfileId
        let workspace = activeProfileId.flatMap { dexterFileWorkspaceStore.workspace(forProfileId: $0) }
        return DexterUniversalCommandSearchContext(
            activeProfileId: activeProfileId,
            activeConversationId: activeHomeConversationIdentifier,
            activeWorkspaceProfileId: workspace?.hasAnyLocation == true ? workspace?.dexterProfileId : nil,
            activeWorkspaceName: workspace?.name
        )
    }

    func searchableConversationMessages(forConversationId conversationId: UUID) -> [DexterChatMessage] {
        if activeHomeConversationIdentifier == conversationId {
            return dexterChatMessages
        }
        return loadArchivedDexterConversationMessages(conversationId: conversationId) ?? []
    }

    func runDexterRoutine(routineID: UUID, runKind: DexterRoutineRunKind) {
        guard let routine = dexterRoutineStore.routine(withId: routineID) else { return }
        guard routine.trigger.kind != .taskCompletion else { return }
        guard !runningDexterRoutineIDs.contains(routineID) else { return }

        if let capabilityBlockReason = DexterRoutineExecutionBridge.capabilityBlockReason(
            routine: routine,
            availableCapabilities: dexterProductCapabilities
        ) {
            dexterRoutineStore.recordRunOutcome(
                routineId: routineID,
                startedAt: Date(),
                succeeded: false,
                summary: capabilityBlockReason
            )
            return
        }

        if dexterProfileStore.activeProfileId != routine.dexterProfileId {
            openDexterProfileWorkspace(profileId: routine.dexterProfileId)
        }

        runningDexterRoutineIDs.insert(routineID)
        let startedAt = Date()
        let userMessage = DexterRoutineExecutionBridge.userMessageForRoutineExecution(routine)
        appendDexterUserChatMessage(userMessage)

        Task { @MainActor in
            defer { runningDexterRoutineIDs.remove(routineID) }
            let routingDecision = DexterFastRequestRouter.route(
                userMessage: userMessage,
                hasPointInvokeScreenCaptures: false,
                forcePointInvokeScreenRoute: false
            )
            do {
                let response = try await DexterUserTurnExecutor.executeCoreRuntimeTurn(
                    transcript: userMessage,
                    inputChannel: .typedText,
                    baseSystemPrompt: DexterAISystemPrompt.companionSystemPrompt,
                    options: dexterModelGenerationOptions(
                        forUserMessage: userMessage,
                        routingDecision: routingDecision
                    ),
                    orchestrator: dexterOrchestrator,
                    onTextChunk: { [weak self] chunk in
                        self?.dexterVoiceCoordinator.appendStreamingResponseChunk(chunk)
                    }
                )
                let summary = response.fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines)
                appendDexterAssistantChatMessage(summary)
                dexterRoutineStore.recordRunOutcome(
                    routineId: routineID,
                    startedAt: startedAt,
                    succeeded: !summary.isEmpty,
                    summary: summary.isEmpty ? "No response generated." : summary
                )
            } catch {
                let failureSummary = "Routine failed: \(error.localizedDescription)"
                appendDexterAssistantChatMessage(failureSummary, isError: true)
                dexterRoutineStore.recordRunOutcome(
                    routineId: routineID,
                    startedAt: startedAt,
                    succeeded: false,
                    summary: failureSummary
                )
            }
        }
    }

    var isPushToTalkEnabled: Bool {
        get { dexterVoiceCoordinator.voiceSettings.isPushToTalkEnabled }
        set {
            var updatedSettings = dexterVoiceCoordinator.voiceSettings
            updatedSettings.isPushToTalkEnabled = newValue
            dexterVoiceCoordinator.voiceSettings = updatedSettings
        }
    }

    var isSpokenResponsesEnabled: Bool {
        get { dexterVoiceCoordinator.voiceSettings.isSpokenResponsesEnabled }
        set {
            var updatedSettings = dexterVoiceCoordinator.voiceSettings
            updatedSettings.isSpokenResponsesEnabled = newValue
            dexterVoiceCoordinator.voiceSettings = updatedSettings
        }
    }

    func submitTextMessageToDexter(_ message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        if DexterRoutineIntentRecognizer.shouldOpenRoutineCreationFlow(for: trimmedMessage) {
            let profileId = dexterProfileStore.activeProfileId ?? dexterProfileStore.profiles.first?.id ?? UUID()
            let draft = DexterRoutineNaturalLanguageParser.parseCreationDraft(
                input: trimmedMessage,
                defaultDexterProfileId: profileId
            )
            dexterRoutineStore.presentCreationDraft(draft)
            appendDexterAssistantChatMessage(
                "I drafted a routine from that. Review the confirmation sheet before I save it."
            )
            return
        }

        lastTranscript = trimmedMessage
        appendDexterUserChatMessage(trimmedMessage)
        DexterAnalytics.trackUserMessageSent(transcript: trimmedMessage)
        sendUserMessageToDexter(trimmedMessage, source: .typedText)
    }

    func startNewDexterConversation() {
        resetActiveConversationTurnState()
        archiveCurrentDexterConversationIfNeeded()
        clearDexterSessionMemory()
        dexterChatMessages = []
        clearActivePointInvokeSession()
        activeHomeConversationIdentifier = nil
        dexterTeachingOverlayStore.dismiss(reason: "new_conversation")
        if let activeProfileId = dexterProfileStore.activeProfileId {
            homeWorkspacePresentation = .dexterWorkspace(activeProfileId)
        }
    }

    func openDexterHomeDashboard() {
        homeWorkspacePresentation = .dashboard
    }

    func openDexterProfileWorkspace(profileId: UUID) {
        if dexterProfileStore.activeProfileId != profileId {
            switchToDexterProfile(profileId: profileId)
        }
        homeWorkspacePresentation = .dexterWorkspace(profileId)
    }

    func switchToDexterProfile(profileId: UUID) {
        guard dexterProfileStore.profile(withId: profileId) != nil else { return }
        guard dexterProfileStore.activeProfileId != profileId else { return }

        resetActiveConversationTurnState()
        archiveCurrentDexterConversationIfNeeded()
        clearDexterSessionMemory()

        dexterProfileStore.setActiveProfile(id: profileId)
        dexterChatMessages = []
        activeHomeConversationIdentifier = nil
        clearActivePointInvokeSession()
        dexterTeachingOverlayStore.dismiss(reason: "dexter_profile_switch")

        if let profile = dexterProfileStore.activeProfile,
           let archivedMessages = loadArchivedDexterConversationMessages(conversationId: profile.conversationID),
           !archivedMessages.isEmpty {
            dexterChatMessages = archivedMessages
            activeHomeConversationIdentifier = profile.conversationID
        }

        reloadDexterMemoryPresentation()
        dexterSuggestionStore.refreshSuggestionsFromAuthorizedContext()
    }

    func createDexterProfileFromHome(
        name: String,
        purpose: String,
        connectedIntegrations: [String],
        workspaceURLs: [URL] = [],
        workspaceName: String? = nil
    ) {
        let profile = dexterProfileStore.createProfile(
            name: name,
            purpose: purpose,
            connectedIntegrations: connectedIntegrations,
            workspace: .empty
        )
        attachFileWorkspacesToProfile(
            profile: profile,
            workspaceURLs: workspaceURLs,
            workspaceName: workspaceName
        )
        openDexterProfileWorkspace(profileId: profile.id)
    }

    func synchronizeProductOnboardingGateOnLaunch() {
        if !dexterProfileStore.profiles.isEmpty && !hasCompletedOnboarding {
            hasCompletedOnboarding = true
            DexterOnboardingStateStore.recordCompleted()
        }
    }

    func skipFirstRunProductOnboardingAndOpenHome() {
        if dexterProfileStore.profiles.isEmpty {
            var draft = DexterOnboardingProfileDraft()
            draft.archetype = .personal
            draft.name = "Personal"
            draft.roleLine = DexterOnboardingArchetype.personal.defaultRoleLine
            draft.characterAppearance = DexterCharacterAppearance.defaultAppearance(
                forCharacterID: DexterOnboardingArchetype.personal.characterID
            )
            _ = dexterProfileStore.createProfileFromOnboardingDraft(draft)
        }
        firstRunOnboardingStore.markSkipped()
        hasCompletedOnboarding = true
        DexterAnalytics.trackOnboardingCompleted(skipped: true)
        finishFirstRunOnboardingNavigation(openComposer: true)
    }

    func finalizeFirstRunOnboardingProfileIfNeeded() {
        guard dexterProfileStore.profiles.isEmpty else { return }
        guard let profile = dexterProfileStore.createProfileFromOnboardingDraft(firstRunOnboardingStore.profileDraft) else {
            return
        }
        let draft = firstRunOnboardingStore.profileDraft
        if !draft.workspaceURLs.isEmpty {
            attachFileWorkspacesToProfile(
                profile: profile,
                workspaceURLs: draft.workspaceURLs,
                workspaceName: draft.workspaceName.isEmpty ? profile.name : draft.workspaceName
            )
        }
        openDexterProfileWorkspace(profileId: profile.id)
    }

    private func attachFileWorkspacesToProfile(
        profile: DexterProfile,
        workspaceURLs: [URL],
        workspaceName: String?
    ) {
        guard !workspaceURLs.isEmpty else { return }
        dexterFileWorkspaceService.addPickedURLs(
            profileId: profile.id,
            profileName: profile.name,
            urls: workspaceURLs,
            workspaceName: workspaceName ?? profile.name
        )
    }

    var dexterHomeUserFirstName: String {
        let fullName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullName.isEmpty else { return "there" }
        return fullName.split(separator: " ").first.map(String.init) ?? fullName
    }

    func lastFailedDexterActionSnapshot() -> DexterProfileFailedActionSnapshot? {
        guard let action = dexterOrchestrator.lastTypedAction else { return nil }
        guard action.state == .failed || action.state == .verificationFailed else { return nil }
        return DexterProfileFailedActionSnapshot(
            actionId: action.id,
            humanReadableDescription: action.humanReadableDescription,
            actionType: action.type
        )
    }

    func openAccountabilityTasks() -> [DexterAccountabilityTask] {
        dexterOrchestrator.memoryStore.allAccountabilityTasks().filter(\.isOpen)
    }

    func handleNotchRecommendationAction(
        _ action: DexterNotchRecommendationAction,
        recommendation: DexterNotchRecommendation
    ) {
        switch action {
        case .approvePendingPermission:
            approvePendingActionConfirmation()
        case .cancelPendingPermission:
            cancelPendingActionConfirmation()
        case .openDexterHome:
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
        case .openIntegrationSettings:
            NotificationCenter.default.post(
                name: .dexterOpenMainWindowSettings,
                object: DexterSettingsPage.integrations
            )
            refreshOpenClawGatewayConnection()
        case .executeProfileWorkSuggestion(let suggestionId, let profileId):
            if let suggestion = dexterProfileWorkSuggestionStore
                .suggestions(forProfileId: profileId)
                .first(where: { $0.id == suggestionId }) {
                executeProfileWorkSuggestion(suggestion)
            }
        case .openConversation(let conversationId):
            if let conversation = dexterRecentConversations.first(where: { $0.id == conversationId }) {
                openRecentDexterConversation(conversation)
            } else {
                NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            }
        case .continueAccountabilityTask(let taskId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            if let task = dexterOrchestrator.memoryStore.allAccountabilityTasks().first(where: { $0.id == taskId }) {
                submitTextMessageToDexter("Help me continue this task: \(task.title)")
            }
        case .retryLastAgentAction:
            retryLastAgentActionFromHUD()
        case .explainLastAgentFailure:
            explainLastAgentFailureFromHUD()
        case .dismiss:
            break
        }
    }

    func executeProfileWorkSuggestion(_ suggestion: DexterProfileWorkSuggestion) {
        dexterProfileWorkSuggestionStore.markAccepted(suggestion)
        openDexterProfileWorkspace(profileId: suggestion.dexterProfileId)

        switch suggestion.action {
        case .openConversation(let conversationId):
            if let conversation = dexterRecentConversations.first(where: { $0.id == conversationId }) {
                openRecentDexterConversation(conversation)
            }
        case .runAgent(let userMessage):
            runAgentTurnFromProfileSuggestion(userMessage: userMessage)
        case .openIntegration:
            NotificationCenter.default.post(
                name: .dexterOpenMainWindowSettings,
                object: DexterSettingsPage.integrations
            )
            refreshOpenClawGatewayConnection()
        case .continueTask(let taskId):
            if let task = dexterOrchestrator.memoryStore.allAccountabilityTasks().first(where: { $0.id == taskId }) {
                runAgentTurnFromProfileSuggestion(userMessage: "Help me continue this task: \(task.title)")
            } else {
                runAgentTurnFromProfileSuggestion(userMessage: suggestion.source.displayDetail)
            }
        case .explain(let subject):
            runAgentTurnFromProfileSuggestion(userMessage: "Explain this using grounded context only: \(subject)")
        case .research(let query):
            runAgentTurnFromProfileSuggestion(userMessage: query)
        }
    }

    private func runAgentTurnFromProfileSuggestion(userMessage: String) {
        let trimmedMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        lastTranscript = trimmedMessage
        appendDexterUserChatMessage(trimmedMessage)
        DexterAnalytics.trackUserMessageSent(transcript: trimmedMessage)
        sendUserMessageToDexter(trimmedMessage, source: .typedText)
    }

    func openRecentDexterConversation(_ conversation: DexterRecentConversationSummary) {
        guard let archivedMessages = loadArchivedDexterConversationMessages(conversationId: conversation.id) else {
            return
        }
        resetActiveConversationTurnState()
        if dexterProfileStore.activeProfileId != conversation.dexterProfileId {
            archiveCurrentDexterConversationIfNeeded()
            clearDexterSessionMemory()
            dexterProfileStore.setActiveProfile(id: conversation.dexterProfileId)
        }
        if activeHomeConversationIdentifier != conversation.id {
            archiveCurrentDexterConversationIfNeeded()
        }
        homeWorkspacePresentation = .dexterWorkspace(conversation.dexterProfileId)
        dexterChatMessages = archivedMessages
        activeHomeConversationIdentifier = conversation.id
        markRecentDexterConversationRead(conversationId: conversation.id)
    }

    func deleteRecentDexterConversation(conversationId: UUID) {
        dexterRecentConversations.removeAll { $0.id == conversationId }
        persistDexterRecentConversations()
        UserDefaults.standard.removeObject(forKey: Self.archivedConversationUserDefaultsKeyPrefix + conversationId.uuidString)
        if activeHomeConversationIdentifier == conversationId {
            dexterChatMessages = []
            activeHomeConversationIdentifier = nil
            dexterChatErrorMessage = nil
            resetActiveConversationTurnState()
            if let activeProfileId = dexterProfileStore.activeProfileId {
                homeWorkspacePresentation = .dexterWorkspace(activeProfileId)
            } else {
                homeWorkspacePresentation = .dashboard
            }
        }
    }

    func renameRecentDexterConversation(conversationId: UUID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = dexterRecentConversations.firstIndex(where: { $0.id == conversationId }) else { return }
        dexterRecentConversations[index].title = String(trimmedTitle.prefix(80))
        persistDexterRecentConversations()
    }

    func deleteDexterChatMessage(messageId: UUID) {
        guard dexterVoiceCoordinator.streamingResponseText.isEmpty else { return }
        guard let index = dexterChatMessages.firstIndex(where: { $0.id == messageId }) else { return }
        dexterChatMessages.remove(at: index)
        if dexterChatMessages.isEmpty {
            if let conversationId = activeHomeConversationIdentifier {
                dexterRecentConversations.removeAll { $0.id == conversationId }
                persistDexterRecentConversations()
                UserDefaults.standard.removeObject(
                    forKey: Self.archivedConversationUserDefaultsKeyPrefix + conversationId.uuidString
                )
                activeHomeConversationIdentifier = nil
            }
        } else {
            syncActiveHomeConversationArchiveIfNeeded()
            if let conversationId = activeHomeConversationIdentifier,
               let firstUserMessage = dexterChatMessages.first(where: { $0.role == .user }),
               let summaryIndex = dexterRecentConversations.firstIndex(where: { $0.id == conversationId }) {
                dexterRecentConversations[summaryIndex].title = String(firstUserMessage.text.prefix(56))
                dexterRecentConversations[summaryIndex].lastUpdated = Date()
                persistDexterRecentConversations()
            }
        }
    }

    func markRecentDexterConversationUnread(conversationId: UUID) {
        guard let index = dexterRecentConversations.firstIndex(where: { $0.id == conversationId }) else { return }
        dexterRecentConversations[index].isUnread = true
        persistDexterRecentConversations()
    }

    func markRecentDexterConversationRead(conversationId: UUID) {
        guard let index = dexterRecentConversations.firstIndex(where: { $0.id == conversationId }) else { return }
        guard dexterRecentConversations[index].isUnread else { return }
        dexterRecentConversations[index].isUnread = false
        persistDexterRecentConversations()
    }

    func requestAccessibilityPermissionFromPanel() {
        _ = WindowPositionManager.requestAccessibilityPermission()
        refreshAllPermissions(caller: "requestAccessibilityPermissionFromPanel", emitVerbosePermissionDiagnostics: true)
    }

    func requestScreenRecordingPermissionFromPanel() {
        _ = WindowPositionManager.requestScreenRecordingPermission()
        refreshAllPermissions(caller: "requestScreenRecordingPermissionFromPanel", emitVerbosePermissionDiagnostics: true)
    }

    func beginPushToTalkFromVoiceControl() {
        beginPushToTalkSession(shouldDismissMenuBarPanel: false)
    }

    func endPushToTalkFromVoiceControl() {
        endPushToTalkSession()
    }

    private func appendDexterUserChatMessage(_ text: String) {
        dexterChatErrorMessage = nil
        dexterSpokenResponseErrorMessage = nil
        ensureActiveHomeConversationIdentifierForCurrentProfile()
        dexterChatMessages.append(DexterChatMessage(role: .user, text: text))
        syncActiveHomeConversationArchiveIfNeeded()
        dexterProfileWorkSuggestionStore.refreshFromAuthorizedContext()
    }

    private func ensureActiveHomeConversationIdentifierForCurrentProfile() {
        guard activeHomeConversationIdentifier == nil else { return }
        let conversationId = UUID()
        activeHomeConversationIdentifier = conversationId
        if let profileId = dexterProfileStore.activeProfileId {
            dexterProfileStore.updatePrimaryConversation(profileId: profileId, conversationId: conversationId)
        }
    }

    private func appendDexterAssistantChatMessage(_ text: String, isError: Bool = false) {
        dexterChatMessages.append(
            DexterChatMessage(role: .assistant, text: text, isError: isError)
        )
        syncActiveHomeConversationArchiveIfNeeded()
    }

    private func archiveCurrentDexterConversationIfNeeded() {
        guard !dexterChatMessages.isEmpty else { return }
        guard let titleMessage = dexterChatMessages.first(where: { $0.role == .user }) else { return }

        let conversationId = activeHomeConversationIdentifier ?? UUID()
        let title = String(titleMessage.text.prefix(56))
        let profileId = dexterProfileStore.activeProfileId ?? DexterSeedProfileIdentifier.personal
        let summary = DexterRecentConversationSummary(
            id: conversationId,
            title: title,
            lastUpdated: Date(),
            isUnread: false,
            dexterProfileId: profileId
        )

        saveArchivedDexterConversationMessages(conversationId: conversationId, messages: dexterChatMessages)

        var updatedRecents = dexterRecentConversations.filter { $0.id != conversationId && $0.title != summary.title }
        updatedRecents.insert(summary, at: 0)
        dexterRecentConversations = Array(updatedRecents.prefix(12))
        persistDexterRecentConversations()
    }

    private func syncActiveHomeConversationArchiveIfNeeded() {
        guard let conversationId = activeHomeConversationIdentifier else { return }
        guard !dexterChatMessages.isEmpty else { return }
        saveArchivedDexterConversationMessages(conversationId: conversationId, messages: dexterChatMessages)
        if let index = dexterRecentConversations.firstIndex(where: { $0.id == conversationId }) {
            dexterRecentConversations[index].lastUpdated = Date()
            persistDexterRecentConversations()
        }
    }

    private func persistDexterRecentConversations() {
        guard let encoded = try? JSONEncoder().encode(dexterRecentConversations) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.dexterRecentConversationsUserDefaultsKey)
    }

    private func loadDexterRecentConversationsFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.dexterRecentConversationsUserDefaultsKey),
              let decoded = try? JSONDecoder().decode([DexterRecentConversationSummary].self, from: data) else {
            return
        }
        dexterRecentConversations = decoded
    }

    private func saveArchivedDexterConversationMessages(conversationId: UUID, messages: [DexterChatMessage]) {
        guard let encoded = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.archivedConversationUserDefaultsKeyPrefix + conversationId.uuidString)
    }

    private func loadArchivedDexterConversationMessages(conversationId: UUID) -> [DexterChatMessage]? {
        guard let data = UserDefaults.standard.data(
            forKey: Self.archivedConversationUserDefaultsKeyPrefix + conversationId.uuidString
        ),
              let decoded = try? JSONDecoder().decode([DexterChatMessage].self, from: data) else {
            return nil
        }
        return decoded
    }

    private func rebuildDexterChatMessagesFromSessionMemory() {
        let exchanges = dexterOrchestrator.memoryStore.recentExchanges(limit: 20)
        guard !exchanges.isEmpty else { return }
        dexterChatMessages = exchanges.flatMap { exchange in
            [
                DexterChatMessage(role: .user, text: exchange.userTranscript),
                DexterChatMessage(role: .assistant, text: exchange.assistantResponse)
            ]
        }
    }

    private static let dexterRecentConversationsUserDefaultsKey = "dexterRecentConversationSummaries"
    private static let archivedConversationUserDefaultsKeyPrefix = "dexterArchivedConversation."

    func refreshActionConfirmationPresentation() {
        actionConfirmationPresentation = dexterOrchestrator.actionConfirmationPresentation()
    }

    func reloadDexterMemoryPresentation() {
        let memoryStore = dexterOrchestrator.memoryStore
        if let profileId = dexterProfileStore.activeProfileId {
            dexterPersistentMemoryEntries = memoryStore.structuredMemories(forProfileId: profileId)
                .map { $0.legacyMemoryEntry() }
        } else {
            dexterPersistentMemoryEntries = memoryStore.allPersistentEntries()
        }
        dexterSessionExchangeCount = memoryStore.sessionExchangeCount
        dexterActiveTaskDescription = memoryStore.activeTaskDescription
        dexterWorkflowContextSummary = memoryStore.workflowContext?.summary
        pendingMemoryInferenceSuggestion = memoryStore.peekPendingInferenceSuggestion()
    }

    func structuredMemories(forProfileId profileId: UUID) -> [DexterStructuredMemoryRecord] {
        dexterOrchestrator.memoryStore.structuredMemories(forProfileId: profileId)
    }

    func updateDexterMemoryEntryContent(memoryId: UUID, newContent: String) {
        if dexterOrchestrator.memoryStore.updateStructuredMemoryContent(memoryId: memoryId, newContent: newContent) {
            reloadDexterMemoryPresentation()
        }
    }

    func confirmPendingMemoryInferenceForActiveDexter() {
        guard let profileId = dexterProfileStore.activeProfileId else { return }
        dexterOrchestrator.memoryStore.confirmPendingInferenceSuggestion(
            binding: .forDexterProfile(profileId)
        )
        reloadDexterMemoryPresentation()
    }

    func declinePendingMemoryInference() {
        dexterOrchestrator.memoryStore.declinePendingInferenceSuggestion()
        reloadDexterMemoryPresentation()
    }

    func clearDexterScopedMemory(forProfileId profileId: UUID) {
        dexterOrchestrator.memoryStore.clearStructuredMemories(forProfileId: profileId)
        reloadDexterMemoryPresentation()
    }

    func removeDexterMemoryEntry(_ entryId: UUID) {
        dexterOrchestrator.memoryStore.removePersistentEntry(id: entryId)
        reloadDexterMemoryPresentation()
    }

    func clearDexterSessionMemory() {
        dexterOrchestrator.memoryStore.clearSessionMemory()
        reloadDexterMemoryPresentation()
    }

    func clearDexterActiveTask() {
        dexterOrchestrator.memoryStore.setActiveTask(description: nil, provenance: .explicitUserRequest)
        reloadDexterMemoryPresentation()
    }

    func clearDexterWorkflowContext() {
        dexterOrchestrator.memoryStore.clearWorkflowContext()
        reloadDexterMemoryPresentation()
    }

    func cancelPendingActionConfirmation() {
        dexterOrchestrator.cancelPendingActionConfirmation()
        refreshActionConfirmationPresentation()
    }

    func approveAgentPermissionFromHUD(allowAlwaysForLowRisk: Bool) {
        if allowAlwaysForLowRisk,
           let confirmation = actionConfirmationPresentation,
           confirmation.riskLevel == .lowRisk {
            autoApproveLowRiskActions = true
            dexterOrchestrator.actionPermissionSettingsStore.isComputerControlAuthorizedForSession = true
        }
        approvePendingActionConfirmation()
    }

    func stopActiveAgentOperationFromHUD() async {
        await dexterOrchestrator.cancelInFlightComputerActionIfNeeded()
        dexterAgentHUDController.dismissTerminalCard()
    }

    func retryLastAgentActionFromHUD() {
        submitTextMessageToDexter("Please retry the last computer action.")
        dexterAgentHUDController.dismissTerminalCard()
    }

    func explainLastAgentFailureFromHUD() {
        submitTextMessageToDexter("Explain what went wrong with the last action.")
        dexterAgentHUDController.dismissTerminalCard()
    }

    func triggerDexterEmergencyStop() async {
        dexterSpokenResponseService.stopSpeaking()
        cancelActiveDexterVoiceInteraction()
        await dexterOrchestrator.activateGlobalEmergencyStop()
        let stopMessage = "Emergency stop activated. Dexter cancelled pending actions and returned to a safe idle state."
        appendDexterAssistantChatMessage(stopMessage)
        dexterVoiceCoordinator.transitionToIdle()
    }

    func recoverDexterToSafeIdle() async {
        let recoveryMessage = await dexterOrchestrator.recoverDexterToSafeIdle(
            stopSpokenOutput: { dexterSpokenResponseService.stopSpeaking() }
        )
        appendDexterAssistantChatMessage(recoveryMessage)
        dexterVoiceCoordinator.transitionToIdle()
    }

    func clearDexterMemoryAndTrustPreferences() {
        dexterOrchestrator.clearDexterMemoryAndRevokeAutomationPreferences()
        reloadDexterMemoryPresentation()
    }

    func releaseDexterEmergencyStop() {
        dexterOrchestrator.releaseEmergencyStopAfterUserAcknowledgement()
    }

    func approvePendingActionConfirmation() {
        pendingActionApprovalTask?.cancel()
        pendingActionApprovalTask = Task {
            _ = await approvePendingActionConfirmationAndWait()
        }
    }

    @discardableResult
    func approvePendingActionConfirmationAndWait() async -> DexterActionExecutionOutcome? {
        actionConfirmationPresentation = nil
        dexterDemonstrationPhaseStore.transition(to: .acting, detail: "Running approved action")
        let outcome = await dexterOrchestrator.approvePendingActionConfirmation()
        refreshActionConfirmationPresentation()
        guard let outcome else { return nil }
        panelLastActionSummary = outcome.verificationReport?.summary ?? outcome.spokenSummary
        dexterVoiceCoordinator.recordAssistantResponse(outcome.spokenSummary)
        appendDexterAssistantChatMessage(outcome.spokenSummary)
        dexterVoiceCoordinator.resetStreamingResponseText()
        processInteractiveOnboardingAfterVerifiedAction(action: outcome.action)
        let spokenOutcome = await DexterSpokenResponseController.speakAssistantTextIfEnabled(
            text: outcome.spokenSummary,
            voiceSettings: dexterVoiceCoordinator.voiceSettings,
            spokenResponseService: dexterSpokenResponseService,
            voiceCoordinator: dexterVoiceCoordinator
        )
        if case .failed(let error) = spokenOutcome {
            dexterSpokenResponseErrorMessage = DexterUserFacingErrorMessage.forTextToSpeechError(error)
        }
        return outcome
    }

    #if DEBUG
    @Published private(set) var developmentContextInspectorSnapshot: DexterDevelopmentContextInspectorSnapshot?

    var isDevelopmentContextInspectorEnabled: Bool {
        DexterDevelopmentContextInspectorSettings.isEnabled
    }

    func setDevelopmentContextInspectorEnabled(_ isEnabled: Bool) {
        DexterDevelopmentContextInspectorSettings.setEnabled(isEnabled)
        if !isEnabled {
            developmentContextInspectorSnapshot = nil
        }
    }
    #endif

    /// The Claude model used for voice responses. Persisted to UserDefaults.
    @Published var selectedModel: String = UserDefaults.standard.string(forKey: "selectedClaudeModel") ?? "claude-sonnet-4-6"

    func setSelectedModel(_ model: String) {
        selectedModel = model
        UserDefaults.standard.set(model, forKey: "selectedClaudeModel")
        dexterOrchestrator.setModelIdentifier(model)
    }

    /// User preference for whether the Dexter cursor should be shown.
    /// When toggled off, the overlay is hidden and push-to-talk is disabled.
    /// Persisted to UserDefaults so the choice survives app restarts.
    @Published var isDexterCursorEnabled: Bool = DexterCursorVisibilityPreferences.readIsCursorOverlayEnabled()

    func setDexterCursorEnabled(_ enabled: Bool) {
        isDexterCursorEnabled = enabled
        DexterCursorVisibilityPreferences.writeIsCursorOverlayEnabled(enabled)
        transientHideTask?.cancel()
        transientHideTask = nil

        if enabled {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        } else {
            dexterTeachingOverlayStore.dismiss(reason: "cursor_disabled")
            overlayWindowManager.hideOverlay()
            isOverlayVisible = false
        }
    }

    /// Whether the user has completed onboarding at least once. Persisted
    /// to UserDefaults so the Start button only appears on first launch.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// Whether the user has submitted their email during onboarding.
    @Published var hasSubmittedEmail: Bool = UserDefaults.standard.bool(forKey: "hasSubmittedEmail")

    /// Saves email submission state and identifies the user in PostHog.
    func submitEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }

        hasSubmittedEmail = true
        UserDefaults.standard.set(true, forKey: "hasSubmittedEmail")

        // Identify user in PostHog
        PostHogSDK.shared.identify(trimmedEmail, userProperties: [
            "email": trimmedEmail
        ])

    }

    func start() {
        synchronizeProductOnboardingGateOnLaunch()
        refreshAllPermissions(caller: "CompanionManager.start", emitVerbosePermissionDiagnostics: true)
        print("🔑 Dexter start — accessibility: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission), mic: \(hasMicrophonePermission), screenContent: \(hasScreenContentPermission), onboarded: \(hasCompletedOnboarding)")
        startPermissionPolling()
        bindDemonstrationPhaseStore()
        dexterAvatarPresence.install(companionManager: self)
        dexterSuggestionStore.install(companionManager: self)
        DexterRoutineDueRoutineCoordinator.install(companionManager: self)
        openClawGatewayHealthMonitor.$capabilityDiscoveryReport
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDexterProductCapabilities()
            }
            .store(in: &voiceInteractionStateCancellables)
        refreshDexterProductCapabilities()
        dexterTeachingOverlayStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
        dexterSuggestionStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
        dexterRoutineStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
        dexterProfileStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
        dexterFileWorkspaceStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
        dexterProfileWorkSuggestionStore.install(companionManager: self)
        dexterProfileWorkSuggestionStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
        bindDexterVoiceCoordinator()
        bindAudioPowerLevel()
        bindMicrophoneRuntimeState()
        bindSpeechToTextErrorPresentation()
        bindShortcutTransitions()
        bindPointInvokeShortcut()
        bindAgentLifecycleAnnouncements()
        globalHomeShortcutMonitor.start()
        dexterOrchestrator.setModelIdentifier(selectedModel)
        loadDexterRecentConversationsFromDisk()
        rebuildDexterChatMessagesFromSessionMemory()
        refreshOllamaConnectionStatus()
        refreshDexterScreenContextUIState()
        scheduleDeferredLaunchWarmup()

        // If the user already completed onboarding AND all permissions are
        // still granted, show the cursor overlay immediately. If permissions
        // were revoked (e.g. signing change), don't show the cursor — the
        // panel will show the permissions UI instead.
        if hasCompletedOnboarding && allPermissionsGranted && isDexterCursorEnabled {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        }
    }

    /// Called by BlueCursorView after the buddy finishes its pointing
    /// animation and returns to cursor-following mode.
    /// Triggers the onboarding sequence — dismisses the panel and restarts
    /// the overlay so the welcome animation and intro video play.
    func triggerOnboarding() {
        NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)

        DexterAnalytics.trackOnboardingStarted()
        interactiveOnboardingFinaleCompletionScheduled = false
        interactiveOnboardingStore.beginInteractiveOnboarding()
        syncInteractiveOnboardingOverlayPrompt()

        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    /// Replays the onboarding experience from the "Watch Onboarding Again"
    /// footer link. Same flow as triggerOnboarding but the cursor overlay
    /// is already visible so we just restart the welcome animation and video.
    func replayOnboarding() {
        NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
        DexterAnalytics.trackOnboardingReplayed()
        interactiveOnboardingFinaleCompletionScheduled = false
        interactiveOnboardingStore.replayInteractiveOnboarding()
        syncInteractiveOnboardingOverlayPrompt()
        overlayWindowManager.hasShownOverlayBefore = false
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    private func stopOnboardingMusic() {
        onboardingMusicFadeTimer?.invalidate()
        onboardingMusicFadeTimer = nil
        onboardingMusicPlayer?.stop()
        onboardingMusicPlayer = nil
    }

    private func startOnboardingMusic() {
        stopOnboardingMusic()
        guard let musicURL = Bundle.main.url(forResource: "ff", withExtension: "mp3") else {
            print("⚠️ Dexter: ff.mp3 not found in bundle")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: musicURL)
            player.volume = 0.3
            player.play()
            self.onboardingMusicPlayer = player

            // After 1m 30s, fade the music out over 3s
            onboardingMusicFadeTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: false) { [weak self] _ in
                self?.fadeOutOnboardingMusic()
            }
        } catch {
            print("⚠️ Dexter: Failed to play onboarding music: \(error)")
        }
    }

    private func fadeOutOnboardingMusic() {
        guard let player = onboardingMusicPlayer else { return }

        let fadeSteps = 30
        let fadeDuration: Double = 3.0
        let stepInterval = fadeDuration / Double(fadeSteps)
        let volumeDecrement = player.volume / Float(fadeSteps)
        var stepsRemaining = fadeSteps

        onboardingMusicFadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            stepsRemaining -= 1
            player.volume -= volumeDecrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.stop()
                self?.onboardingMusicPlayer = nil
                self?.onboardingMusicFadeTimer = nil
            }
        }
    }

    func clearDetectedElementLocation() {
        detectedElementScreenLocation = nil
        detectedElementDisplayFrame = nil
        detectedElementBubbleText = nil
    }

    func stop() {
        globalPushToTalkShortcutMonitor.stop()
        buddyDictationManager.cancelCurrentDictation()
        dexterTeachingOverlayStore.dismiss(reason: "app_stop")
        overlayWindowManager.hideOverlay()
        transientHideTask?.cancel()

        userTurnController.cancelActiveTurn(
            spokenResponseService: dexterSpokenResponseService,
            voiceCoordinator: dexterVoiceCoordinator,
            orchestrator: dexterOrchestrator
        )
        shortcutTransitionCancellable?.cancel()
        voiceCoordinatorForwardCancellable?.cancel()
        voiceInteractionStateCancellables.removeAll()
        audioPowerCancellable?.cancel()
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
    }

    func refreshAllPermissions(
        caller: String = "unspecified",
        emitVerbosePermissionDiagnostics: Bool = true
    ) {
        let previouslyHadAccessibility = hasAccessibilityPermission
        let previouslyHadScreenRecording = hasScreenRecordingPermission
        let previouslyHadMicrophone = hasMicrophonePermission
        let previouslyHadAll = allPermissionsGranted
        let previousScreenPermissionState = screenPermissionState

        let currentlyHasAccessibility = WindowPositionManager.hasAccessibilityPermission()
        hasAccessibilityPermission = currentlyHasAccessibility

        if currentlyHasAccessibility {
            globalPushToTalkShortcutMonitor.start()
        } else {
            globalPushToTalkShortcutMonitor.stop()
        }

        hasScreenRecordingPermission = WindowPositionManager.hasScreenRecordingPermission()

        let micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        hasMicrophonePermission = micAuthStatus == .authorized
        syncMicrophonePermissionState(from: micAuthStatus)

        screenPermissionState = CGPreflightScreenCaptureAccess() ? .granted : .denied

        let permissionValuesChanged = previouslyHadAccessibility != hasAccessibilityPermission
            || previouslyHadScreenRecording != hasScreenRecordingPermission
            || previouslyHadMicrophone != hasMicrophonePermission
            || previousScreenPermissionState != screenPermissionState

        if permissionValuesChanged || caller != "startPermissionPollingTimer" {
            DexterPermissionCheckLog.log(caller: caller, permissionValuesChanged: permissionValuesChanged)
        }

        if emitVerbosePermissionDiagnostics || permissionValuesChanged {
            DexterMicPermissionLog.log(status: micAuthStatus)
            DexterPermissionDiagnostics.logMicrophoneAuthorizationStatus()
            DexterPermissionDiagnostics.logSelectedAudioInputDevice()
        }

        // Debug: log permission state on changes
        if previouslyHadAccessibility != hasAccessibilityPermission
            || previouslyHadScreenRecording != hasScreenRecordingPermission
            || previouslyHadMicrophone != hasMicrophonePermission {
            print("🔑 Permissions — accessibility: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission), mic: \(hasMicrophonePermission), screenContent: \(hasScreenContentPermission)")
        }

        // Track individual permission grants as they happen
        if !previouslyHadAccessibility && hasAccessibilityPermission {
            DexterAnalytics.trackPermissionGranted(permission: "accessibility")
        }
        if !previouslyHadScreenRecording && hasScreenRecordingPermission {
            DexterAnalytics.trackPermissionGranted(permission: "screen_recording")
            hasVerifiedScreenCaptureProbe = false
            runScreenCaptureCapabilityProbeIfNeeded()
        }
        if !previouslyHadMicrophone && hasMicrophonePermission {
            DexterAnalytics.trackPermissionGranted(permission: "microphone")
        }
        // Screen content permission is persisted — once the user has approved the
        // SCShareableContent picker, we don't need to re-check it.
        if !hasScreenContentPermission {
            hasScreenContentPermission = UserDefaults.standard.bool(forKey: "hasScreenContentPermission")
        }

        if !previouslyHadAll && allPermissionsGranted {
            DexterAnalytics.trackAllPermissionsGranted()
        }

        refreshDexterScreenContextUIState(logScreenPermissionDiagnostics: emitVerbosePermissionDiagnostics || permissionValuesChanged)
    }

    /// Triggers the macOS screen content picker by performing a dummy
    /// screenshot capture. Once the user approves, we persist the grant
    /// so they're never asked again during onboarding.
    @Published private(set) var isRequestingScreenContent = false

    func requestScreenContentPermission() {
        guard !isRequestingScreenContent else { return }
        isRequestingScreenContent = true
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    await MainActor.run { isRequestingScreenContent = false }
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 320
                config.height = 240
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                // Verify the capture actually returned real content — a 0x0 or
                // fully-empty image means the user denied the prompt.
                let didCapture = image.width > 0 && image.height > 0
                print("🔑 Screen content capture result — width: \(image.width), height: \(image.height), didCapture: \(didCapture)")
                await MainActor.run {
                    isRequestingScreenContent = false
                    guard didCapture else { return }
                    hasScreenContentPermission = true
                    UserDefaults.standard.set(true, forKey: "hasScreenContentPermission")
                    DexterAnalytics.trackPermissionGranted(permission: "screen_content")

                    // If onboarding was already completed, show the cursor overlay now
                    if hasCompletedOnboarding && allPermissionsGranted && !isOverlayVisible && isDexterCursorEnabled {
                        overlayWindowManager.hasShownOverlayBefore = true
                        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                        isOverlayVisible = true
                    }
                }
            } catch {
                print("⚠️ Screen content permission request failed: \(error)")
                await MainActor.run { isRequestingScreenContent = false }
            }
        }
    }

    // MARK: - Private

    /// Triggers the system microphone prompt if the user has never been asked.
    /// Once granted/denied the status sticks and polling picks it up.
    private func promptForMicrophoneIfNotDetermined() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        syncMicrophonePermissionState(from: authorizationStatus)
        DexterMicPermissionLog.log(status: authorizationStatus)
        guard authorizationStatus == .notDetermined else { return }
        NSApplication.shared.activate(ignoringOtherApps: true)
        microphonePermissionState = .requesting
        DexterMicPermissionLog.log(status: authorizationStatus, requestStarted: true)
        DexterPermissionDiagnostics.logMicrophoneRequestAccessInvoked()
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            let updatedStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            DexterMicPermissionLog.log(status: updatedStatus, requestResult: granted)
            DexterPermissionDiagnostics.logMicrophoneRequestAccessResult(granted: granted)
            Task { @MainActor [weak self] in
                self?.hasMicrophonePermission = granted
                self?.syncMicrophonePermissionState(from: updatedStatus)
            }
        }
    }

    private func syncMicrophonePermissionState(from authorizationStatus: AVAuthorizationStatus) {
        switch authorizationStatus {
        case .authorized:
            microphonePermissionState = .authorized
        case .denied:
            microphonePermissionState = .denied
        case .notDetermined:
            if microphonePermissionState != .requesting {
                microphonePermissionState = .notDetermined
            }
        case .restricted:
            microphonePermissionState = .unavailable
        @unknown default:
            microphonePermissionState = .unavailable
        }
    }

    /// Polls all permissions frequently so the UI updates live after the
    /// user grants them in System Settings. Screen Recording is the exception —
    /// macOS requires an app restart for that one to take effect.
    private func startPermissionPolling() {
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllPermissions(
                    caller: "startPermissionPollingTimer",
                    emitVerbosePermissionDiagnostics: false
                )
            }
        }
    }

    private func bindAudioPowerLevel() {
        audioPowerCancellable = buddyDictationManager.$currentAudioPowerLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] powerLevel in
                self?.currentAudioPowerLevel = powerLevel
            }

        buddyDictationManager.$microphoneHardwareInputDetected
            .receive(on: DispatchQueue.main)
            .assign(to: &$microphoneHardwareInputDetected)
    }

    private var microphoneRuntimeStateCancellables = Set<AnyCancellable>()

    private func bindMicrophoneRuntimeState() {
        buddyDictationManager.$isPreparingToRecord
            .combineLatest(
                buddyDictationManager.$isRecordingFromKeyboardShortcut,
                buddyDictationManager.$isRecordingFromMicrophoneButton,
                buddyDictationManager.$isFinalizingTranscript
            )
            .combineLatest(buddyDictationManager.$lastMicrophoneErrorMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recordingTuple, lastMicrophoneErrorMessage in
                guard let self else { return }
                let isPreparing = recordingTuple.0
                let isShortcutRecording = recordingTuple.1
                let isMicrophoneButtonRecording = recordingTuple.2
                let isFinalizing = recordingTuple.3

                if isPreparing {
                    self.microphoneRuntimeState = .starting
                    return
                }
                if isShortcutRecording || isMicrophoneButtonRecording {
                    self.microphoneRuntimeState = .listening
                    self.microphoneInputErrorMessage = nil
                    return
                }
                if isFinalizing {
                    self.microphoneRuntimeState = .processing
                    return
                }
                if let lastMicrophoneErrorMessage, !lastMicrophoneErrorMessage.isEmpty {
                    self.microphoneRuntimeState = .error
                    self.microphoneInputErrorMessage = lastMicrophoneErrorMessage
                    return
                }
                self.microphoneRuntimeState = .idle
                self.microphoneInputErrorMessage = nil
            }
            .store(in: &microphoneRuntimeStateCancellables)
    }

    private func bindSpeechToTextErrorPresentation() {
        buddyDictationManager.$speechToTextErrorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speechToTextErrorMessage in
                guard let self else { return }
                guard let speechToTextErrorMessage, !speechToTextErrorMessage.isEmpty else {
                    self.voiceInputErrorPresentation = nil
                    return
                }
                guard !self.buddyDictationManager.isActivelyRecordingAudio else { return }

                let presentation = DexterSpeechToTextUserFacing.presentationRemappingLegacyUserString(
                    speechToTextErrorMessage
                )
                self.voiceInputErrorPresentation = presentation
                self.dexterVoiceCoordinator.transitionToError()
                DexterDiagnosticLog.stt("voice input error (user): \(presentation.headline)")
            }
            .store(in: &microphoneRuntimeStateCancellables)
    }

    func clearVoiceInputErrorPresentation() {
        voiceInputErrorPresentation = nil
        buddyDictationManager.clearSpeechToTextErrorMessage()
        dexterVoiceCoordinator.clearVoiceInputError()
    }

    func openVoiceSettingsFromVoiceInputError() {
        NotificationCenter.default.post(name: .dexterOpenVoiceSettings, object: nil)
    }

    private func bindDemonstrationPhaseStore() {
        demonstrationPhaseForwardCancellable = dexterRuntimeUIStateStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        interactiveOnboardingStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &voiceInteractionStateCancellables)
    }

    private func bindAgentLifecycleAnnouncements() {
        dexterRuntimeUIStateStore.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] runtimeUIState in
                self?.announceAgentLifecycleIfNeeded(for: runtimeUIState)
            }
            .store(in: &voiceInteractionStateCancellables)
    }

    private func announceAgentLifecycleIfNeeded(for runtimeUIState: DexterRuntimeUIState) {
        guard DexterAgentSettingsStore.shared.speakWhenAgentStartsOrFinishes else { return }
        guard dexterRuntimeUIStateStore.activeExecutionSnapshot != nil else { return }

        let announcementText: String?
        switch runtimeUIState {
        case .acting where lastAgentLifecycleAnnouncementState != .acting:
            announcementText = "Running the action."
        case .done where lastAgentLifecycleAnnouncementState == .acting
            || lastAgentLifecycleAnnouncementState == .verifying:
            announcementText = "Action finished."
        case .failed where lastAgentLifecycleAnnouncementState == .acting
            || lastAgentLifecycleAnnouncementState == .verifying:
            announcementText = "Action could not be completed."
        default:
            announcementText = nil
        }

        lastAgentLifecycleAnnouncementState = runtimeUIState

        guard let announcementText else { return }

        Task {
            _ = await DexterSpokenResponseController.speakAssistantTextIfEnabled(
                text: announcementText,
                voiceSettings: DexterVoiceSettings(
                    isPushToTalkEnabled: isPushToTalkEnabled,
                    isSpokenResponsesEnabled: isSpokenResponsesEnabled,
                    preferredMacSpeechVoiceIdentifier: preferredMacSpeechVoiceIdentifier
                ),
                spokenResponseService: dexterSpokenResponseService,
                voiceCoordinator: dexterVoiceCoordinator
            )
        }
    }

    private func bindDexterVoiceCoordinator() {
        dexterVoiceCoordinator.bindDictationManager(buddyDictationManager)
        voiceCoordinatorForwardCancellable = dexterVoiceCoordinator.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        dexterVoiceCoordinator.$interactionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interactionState in
                guard let self else { return }
                self.dexterRuntimeUIStateStore.setVoiceInteractionState(interactionState)
                if interactionState == .idle && !self.userTurnController.hasActiveResponseTask {
                    self.scheduleTransientHideIfNeeded()
                }
            }
            .store(in: &voiceInteractionStateCancellables)
    }

    private var voiceInteractionStateCancellables = Set<AnyCancellable>()

    private func cancelActiveDexterVoiceInteraction() {
        if dexterOrchestrator.pendingActionExecution != nil {
            dexterOrchestrator.cancelPendingActionConfirmation()
            refreshActionConfirmationPresentation()
        }
        userTurnController.cancelActiveTurn(
            spokenResponseService: dexterSpokenResponseService,
            voiceCoordinator: dexterVoiceCoordinator,
            orchestrator: dexterOrchestrator
        )
    }

    /// Clears in-flight model/TTS/action state when switching or starting conversations.
    private func resetActiveConversationTurnState() {
        cancelActiveDexterVoiceInteraction()
        dexterVoiceCoordinator.resetStreamingResponseText()
        dexterChatErrorMessage = nil
        dexterSpokenResponseErrorMessage = nil
    }

    /// Network, OpenClaw, workspace migration, and mic prompt after first frame — keeps launch responsive.
    private func scheduleDeferredLaunchWarmup() {
        deferredLaunchWarmupTask?.cancel()
        deferredLaunchWarmupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            dexterFileWorkspaceService.migrateAllLegacyProfileWorkspaces(profiles: dexterProfileStore.profiles)
            dexterOrchestrator.warmUpModelConnectionIfNeeded()
            refreshOpenClawGatewayConnection()
            runScreenCaptureCapabilityProbeIfNeeded()
            promptForMicrophoneIfNotDetermined()
            evaluateDueDexterRoutines()
        }
    }

    private func bindShortcutTransitions() {
        shortcutTransitionCancellable = globalPushToTalkShortcutMonitor
            .shortcutTransitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                self?.handleShortcutTransition(transition)
            }
    }

    private func bindPointInvokeShortcut() {
        pointInvokeShortcutCancellable = globalPushToTalkShortcutMonitor
            .pointInvokePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handlePointInvokeShortcut()
            }
    }

    func handlePointInvokeShortcut() {
        refreshAllPermissions(caller: "handlePointInvokeShortcut", emitVerbosePermissionDiagnostics: true)
        cancelActiveDexterVoiceInteraction()

        let pointerLocationInScreenSpace = NSEvent.mouseLocation
        isPreparingPointInvokeSession = true
        dexterScreenContextUIState = .analyzingScreen

        NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
        NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
        NotificationCenter.default.post(name: .dexterHomeFocusChat, object: nil)

        ensureCompanionOverlayVisibleForFirstRunInteraction()

        Task {
            let session = await dexterOrchestrator.preparePointInvokeSession(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                hasPersistedScreenContentGrant: hasScreenContentPermission
            )

            activePointInvokeSession = session
            lastDexterContextSnapshot = session.contextSnapshot
            isPreparingPointInvokeSession = false
            interactiveOnboardingStore.registerPointCaptureIfNeeded()
            syncInteractiveOnboardingOverlayPrompt()
            registerFirstRunPointCaptureIfNeeded(session: session)
            presentPointAskCaptureUI(for: session)

            if session.contextSnapshot.screenCaptureAvailability == .permissionMissing {
                dexterScreenContextUIState = .permissionRequired
            } else if session.screenCaptureSnapshots.isEmpty {
                dexterScreenContextUIState = .unavailable
            } else {
                dexterScreenContextUIState = .ready
            }
        }
    }

    private func presentPointAskCaptureUI(for session: DexterPointInvokeSession) {
        if !overlayWindowManager.isShowingOverlay() {
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        }
        dexterTeachingOverlayStore.presentPointAskCaptureMarker(session: session)
        DexterAnalytics.trackPointAskCapture(
            hasSemanticTarget: session.pointerSemanticTarget != nil,
            evidenceSources: session.pointerSemanticTarget?.evidence.map(\.source.rawValue) ?? []
        )
    }

    private func dexterModelGenerationOptions(
        forUserMessage userMessage: String,
        routingDecision: DexterRequestRoutingDecision
    ) -> DexterModelGenerationOptions {
        if let activePointInvokeSession {
            return DexterModelGenerationOptions(
                screenCaptureOverride: activePointInvokeSession.screenCaptureSnapshots.isEmpty
                    ? nil
                    : activePointInvokeSession.screenCaptureSnapshots,
                includeSessionConversationHistory: true,
                hasPersistedScreenContentGrant: hasScreenContentPermission,
                pointerLocationInScreenSpaceOverride: activePointInvokeSession.pointerLocationInScreenSpace,
                usePointAtContextRelevancePlan: true,
                routingDecision: routingDecision,
                activeDexterProfileId: dexterProfileStore.activeProfileId
            )
        }

        return DexterModelGenerationOptions(
            hasPersistedScreenContentGrant: hasScreenContentPermission,
            pointerLocationInScreenSpaceOverride: routingDecision.pinPointerForContext
                ? NSEvent.mouseLocation
                : nil,
            routingDecision: routingDecision,
            activeDexterProfileId: dexterProfileStore.activeProfileId,
            activeFileWorkspaceId: activeFileWorkspaceIdentifierForMemoryBinding()
        )
    }

    private func activeFileWorkspaceIdentifierForMemoryBinding() -> UUID? {
        guard let profileId = dexterProfileStore.activeProfileId else { return nil }
        return dexterFileWorkspaceStore.workspace(forProfileId: profileId)?.id
    }

    private func handleShortcutTransition(_ transition: BuddyPushToTalkShortcut.ShortcutTransition) {
        switch transition {
        case .pressed:
            beginPushToTalkSession(shouldDismissMenuBarPanel: true)
        case .released:
            endPushToTalkSession()
        case .none:
            break
        }
    }

    private func beginPushToTalkSession(shouldDismissMenuBarPanel: Bool) {
        guard dexterVoiceCoordinator.voiceSettings.isPushToTalkEnabled else { return }
        guard !buddyDictationManager.isDictationInProgress else { return }
        guard !showOnboardingVideo else { return }

        DexterDiagnosticLog.voice("voice input started")
        DexterDiagnosticLog.stt("STT session started")
        DexterCoreExecutionPipelineLog.log(phase: .microphone, detail: "capture")

        transientHideTask?.cancel()
        transientHideTask = nil

        if !isDexterCursorEnabled && !isOverlayVisible {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        }

        if shouldDismissMenuBarPanel {
            NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
        }

        activePushToTalkSessionIdentifier = userTurnController.pushToTalkSessionTracker.beginSession()
        DexterCoreExecutionPipelineLog.log(phase: .pushToTalk)
        dexterVoiceCoordinator.prepareForPushToTalkCapture()
        cancelActiveDexterVoiceInteraction()
        clearDetectedElementLocation()

        if showOnboardingPrompt {
            withAnimation(.easeOut(duration: 0.3)) {
                onboardingPromptOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.showOnboardingPrompt = false
                self.onboardingPromptText = ""
            }
        }

        DexterAnalytics.trackPushToTalkStarted()
        promptForMicrophoneIfNotDetermined()
        clearVoiceInputErrorPresentation()

        pendingKeyboardShortcutStartTask?.cancel()
        pendingKeyboardShortcutStartTask = Task {
            await buddyDictationManager.startPushToTalkFromKeyboardShortcut(
                currentDraftText: "",
                updateDraftText: { _ in
                    // Partial transcripts are hidden (waveform-only UI)
                },
                submitDraftText: { [weak self] finalTranscript in
                    DexterCoreExecutionPipelineLog.log(phase: .speechToText, detail: "finalized")
                    DexterMicDiagnosticLog.log("transcript received (\(finalTranscript.count) characters)")
                    DexterDiagnosticLog.stt("transcript received (\(finalTranscript.count) characters)")
                    self?.voiceInputErrorPresentation = nil
                    self?.dexterVoiceCoordinator.transitionToThinking()
                    self?.lastTranscript = finalTranscript
                    self?.appendDexterUserChatMessage(finalTranscript)
                    DexterAnalytics.trackUserMessageSent(transcript: finalTranscript)
                    DexterDiagnosticLog.voice("transcript sent to core runtime")
                    self?.sendUserMessageToDexter(finalTranscript, source: .pushToTalkTranscript)
                }
            )
        }
    }

    private func endPushToTalkSession() {
        DexterAnalytics.trackPushToTalkReleased()
        DexterPerformanceTiming.markHotkeyReleased()
        DexterCoreExecutionPipelineLog.log(phase: .microphone, detail: "release")

        if let activePushToTalkSessionIdentifier,
           userTurnController.pushToTalkSessionTracker.handleRelease(for: activePushToTalkSessionIdentifier) {
            buddyDictationManager.handleKeyboardShortcutReleased()
        } else if activePushToTalkSessionIdentifier == nil {
            buddyDictationManager.handleKeyboardShortcutReleased()
        }

        pendingKeyboardShortcutStartTask = nil
    }

    // MARK: - Dexter Voice response pipeline

    /// Speech-to-text (push-to-talk) or typed text → streamed model response → optional TTS.
    private func sendUserMessageToDexter(_ transcript: String, source: DexterUserInputChannel) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            DexterDiagnosticLog.voice("ignored empty user message (source=\(source))")
            dexterVoiceCoordinator.transitionToIdle()
            return
        }

        cancelActiveDexterVoiceInteraction()
        let turnGeneration = userTurnController.beginTurn()

        let responseTask = Task {
            defer {
                userTurnController.setResponseTask(nil)
            }
            _ = DexterTurnTrace.beginTurn()
            var turnOutcome: DexterTurnOutcome?
            var turnOperationalOutcome: DexterOperationalOutcomeCategory?
            DexterPerformanceTiming.markInputReceived()
            let routingDecision = DexterFastRequestRouter.route(
                userMessage: trimmedTranscript,
                hasPointInvokeScreenCaptures: activePointInvokeSession?.screenCaptureSnapshots.isEmpty == false,
                forcePointInvokeScreenRoute: activePointInvokeSession != nil
            )
            DexterPerformanceTiming.markRoutingCompleted(route: routingDecision.route)
            let screenRecordingPreflightGranted = CGPreflightScreenCaptureAccess()
            let userRequestedScreenContext = routingDecision.requiresScreenCapture

            defer {
                DexterPerformanceTiming.markResponseCompleted()
                if turnOutcome == nil {
                    if Task.isCancelled {
                        turnOutcome = .cancelled
                    } else {
                        turnOutcome = .error
                    }
                }
                if userRequestedScreenContext {
                    switch turnOutcome {
                    case .success:
                        DexterVisionTiming.markTurnCompleted()
                    case .timeout:
                        DexterVisionTiming.logTimeout(afterSeconds: 90)
                    case .error, .cancelled, .none:
                        DexterVisionTiming.markTurnCompleted()
                    }
                }
                let resolvedTurnOutcome = turnOutcome ?? .error
                let resolvedOperationalOutcome = turnOperationalOutcome
                    ?? DexterTurnOutcomeResolver.operationalOutcome(
                        for: resolvedTurnOutcome,
                        orchestrator: dexterOrchestrator
                    )
                DexterTurnTrace.finish(
                    outcome: resolvedTurnOutcome,
                    operationalOutcome: resolvedOperationalOutcome
                )
                refreshDexterScreenContextUIState(logScreenPermissionDiagnostics: false)
                if dexterVoiceCoordinator.interactionState == .thinking {
                    dexterVoiceCoordinator.transitionToIdle()
                }
                if source == .pushToTalkTranscript, !Task.isCancelled {
                    scheduleTransientHideIfNeeded()
                }
            }

            dexterVoiceCoordinator.resetStreamingResponseText()
            dexterSpokenResponseErrorMessage = nil
            dexterVoiceCoordinator.transitionToThinking()
            DexterDiagnosticLog.model("generation started")

            DexterTurnTrace.log("USER REQUEST: \(trimmedTranscript)")
            DexterTurnTrace.log("request_route=\(routingDecision.route.rawValue)")
            DexterTurnTrace.log("visualContextRequired=\(userRequestedScreenContext)")
            DexterTurnTrace.log("orchestrator started")
            if userRequestedScreenContext {
                dexterScreenContextUIState = .analyzingScreen
            }

            if userRequestedScreenContext && !screenRecordingPreflightGranted {
                DexterDiagnosticLog.vision("screen context unavailable — CGPreflight false")
            }

            let hasFrozenPointInvokeCaptures = activePointInvokeSession?.screenCaptureSnapshots.isEmpty == false
            if userRequestedScreenContext && !screenRecordingPreflightGranted && !hasFrozenPointInvokeCaptures {
                let unavailableMessage = DexterUserFacingErrorMessage.forScreenContextUnavailable()
                dexterChatErrorMessage = unavailableMessage
                appendDexterAssistantChatMessage(unavailableMessage, isError: true)
                dexterVoiceCoordinator.recordAssistantResponse(unavailableMessage)
                dexterVoiceCoordinator.resetStreamingResponseText()
                dexterVoiceCoordinator.transitionToIdle()
                turnOutcome = .success
                return
            }

            do {
                let orchestratorResponse = try await DexterUserTurnExecutor.executeCoreRuntimeTurn(
                    transcript: trimmedTranscript,
                    inputChannel: source,
                    baseSystemPrompt: DexterAISystemPrompt.companionSystemPrompt,
                    options: dexterModelGenerationOptions(
                        forUserMessage: trimmedTranscript,
                        routingDecision: routingDecision
                    ),
                    orchestrator: dexterOrchestrator,
                    onTextChunk: { [weak self] chunk in
                        if !chunk.isEmpty {
                            DexterPerformanceTiming.markFirstTokenReceived()
                        }
                        self?.dexterVoiceCoordinator.appendStreamingResponseChunk(chunk)
                    }
                )

                DexterTurnTrace.log("orchestrator finished")
                DexterDiagnosticLog.model("model response received")

                guard !Task.isCancelled,
                      userTurnController.isTurnStillActive(generation: turnGeneration) else {
                    turnOutcome = .cancelled
                    dexterVoiceCoordinator.transitionToIdle()
                    return
                }

                updateDevelopmentContextInspectorIfNeeded(from: orchestratorResponse.context)
                lastDexterContextSnapshot = DexterContextSnapshotBuilder.make(
                    from: orchestratorResponse.context,
                    permissionState: DexterContextPermissionState(
                        hasScreenRecordingPermission: hasScreenRecordingPermission,
                        hasAccessibilityPermission: hasAccessibilityPermission,
                        hasScreenContentPermission: hasScreenContentPermission
                    ),
                    userRequestedScreenContext: userRequestedScreenContext
                )
                refreshActionConfirmationPresentation()

                let fullResponseText = orchestratorResponse.fullResponseText
                dexterDemonstrationSessionStore.recordProposedFix(fromAssistantResponse: fullResponseText)

                let screenCaptureSnapshots = orchestratorResponse.context.screenCaptures
                let screenCaptures = screenCaptureSnapshots.map { CompanionScreenCapture(snapshot: $0) }

                let responseTextForDisplay = DexterFixTagParser.spokenText(removingFixTagFrom: fullResponseText)
                // Parse the [POINT:...] tag from Claude's response
                let parseResult = Self.parsePointingCoordinates(from: responseTextForDisplay)
                let spokenText = parseResult.spokenText
                dexterVoiceCoordinator.recordAssistantResponse(spokenText)
                appendDexterAssistantChatMessage(spokenText)
                dexterVoiceCoordinator.resetStreamingResponseText()
                dexterVoiceCoordinator.transitionToIdle()
                registerFirstRunProgressAfterSuccessfulTurn(source: source)

                // Handle element pointing if Claude returned coordinates.
                // Thinking already ended; overlay can show the triangle for pointing.
                let hasPointCoordinate = parseResult.coordinate != nil

                // Pick the screen capture matching Claude's screen number,
                // falling back to the cursor screen if not specified.
                let targetScreenCapture: CompanionScreenCapture? = {
                    if let screenNumber = parseResult.screenNumber,
                       screenNumber >= 1 && screenNumber <= screenCaptures.count {
                        return screenCaptures[screenNumber - 1]
                    }
                    return screenCaptures.first(where: { $0.isCursorScreen })
                }()

                var resolvedGlobalTargetForTeaching: CGPoint?
                var resolvedDisplayFrameForTeaching: CGRect?

                if let pointCoordinate = parseResult.coordinate,
                   let targetScreenCapture {
                    // Claude's coordinates are in the screenshot's pixel space
                    // (top-left origin, e.g. 1280x831). Scale to the display's
                    // point space (e.g. 1512x982), then convert to AppKit global coords.
                    let screenshotWidth = CGFloat(targetScreenCapture.screenshotWidthInPixels)
                    let screenshotHeight = CGFloat(targetScreenCapture.screenshotHeightInPixels)
                    let displayWidth = CGFloat(targetScreenCapture.displayWidthInPoints)
                    let displayHeight = CGFloat(targetScreenCapture.displayHeightInPoints)
                    let displayFrame = targetScreenCapture.displayFrame

                    // Clamp to screenshot coordinate space
                    let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
                    let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))

                    // Scale from screenshot pixels to display points
                    let displayLocalX = clampedX * (displayWidth / screenshotWidth)
                    let displayLocalY = clampedY * (displayHeight / screenshotHeight)

                    // Convert from top-left origin (screenshot) to bottom-left origin (AppKit)
                    let appKitY = displayHeight - displayLocalY

                    // Convert display-local coords to global screen coords
                    let globalLocation = CGPoint(
                        x: displayLocalX + displayFrame.origin.x,
                        y: appKitY + displayFrame.origin.y
                    )

                    detectedElementScreenLocation = globalLocation
                    detectedElementDisplayFrame = displayFrame
                    resolvedGlobalTargetForTeaching = globalLocation
                    resolvedDisplayFrameForTeaching = displayFrame
                    DexterAnalytics.trackElementPointed(elementLabel: parseResult.elementLabel)
                    print("🎯 Element pointing: (\(Int(pointCoordinate.x)), \(Int(pointCoordinate.y))) → \"\(parseResult.elementLabel ?? "element")\"")
                } else {
                    print("🎯 Element pointing: \(parseResult.elementLabel ?? "no element")")
                }

                updateTeachingOverlayAfterModelTurn(
                    orchestratorResponse: orchestratorResponse,
                    parseResult: parseResult,
                    globalTargetPoint: resolvedGlobalTargetForTeaching,
                    targetDisplayFrame: resolvedDisplayFrameForTeaching
                )
                dexterSuggestionStore.refreshSuggestionsFromAuthorizedContext()

                dexterOrchestrator.recordConversationExchange(
                    userTranscript: trimmedTranscript,
                    assistantResponse: spokenText
                )
                if orchestratorResponse.responseMode == .act {
                    panelLastActionSummary = orchestratorResponse.fullResponseText
                } else if let lastAction = dexterOrchestrator.lastTypedAction,
                          lastAction.state == .completed || lastAction.state == .verificationFailed || lastAction.state == .failed {
                    panelLastActionSummary = orchestratorResponse.fullResponseText
                }
                reloadDexterMemoryPresentation()

                let exchangeCount = dexterOrchestrator.memoryStore.recentExchanges(limit: 10).count
                print("🧠 Conversation history: \(exchangeCount) exchanges")

                DexterAnalytics.trackAIResponseReceived(response: spokenText)

                if let onboardingTurnOutcome = await processInteractiveOnboardingAfterModelTurn(
                    userTranscript: trimmedTranscript,
                    orchestratorResponse: orchestratorResponse
                ) {
                    turnOutcome = onboardingTurnOutcome
                } else {
                    turnOutcome = DexterTurnOutcomeResolver.resolve(
                        orchestrator: dexterOrchestrator,
                        orchestratorResponse: orchestratorResponse
                    )
                }
                turnOperationalOutcome = DexterTurnOutcomeResolver.operationalOutcome(
                    for: turnOutcome ?? .error,
                    orchestrator: dexterOrchestrator
                )

                if userTurnController.isTurnStillActive(generation: turnGeneration) {
                    let spokenOutcome = await DexterSpokenResponseController.speakAssistantTextIfEnabled(
                        text: spokenText,
                        voiceSettings: dexterVoiceCoordinator.voiceSettings,
                        spokenResponseService: dexterSpokenResponseService,
                        voiceCoordinator: dexterVoiceCoordinator
                    )
                    if case .failed(let error) = spokenOutcome {
                        dexterSpokenResponseErrorMessage = DexterUserFacingErrorMessage.forTextToSpeechError(error)
                    }
                }
            } catch is CancellationError {
                dexterRuntimeUIStateStore.reset()
                turnOutcome = .cancelled
                dexterVoiceCoordinator.transitionToIdle()
            } catch {
                DexterAnalytics.trackResponseError(error: error.localizedDescription)
                DexterDiagnosticLog.model("generation failed: \(error.localizedDescription)")
                if error is DexterModelRequestTimeoutError
                    || error is DexterContextAssemblyTimeoutError {
                    DexterTurnTrace.log("MODEL TIMEOUT")
                } else {
                    DexterTurnTrace.log("MODEL ERROR \(error.localizedDescription)")
                }
                let userMessage: String
                if userRequestedScreenContext && !screenRecordingPreflightGranted {
                    userMessage = DexterUserFacingErrorMessage.forScreenContextUnavailable()
                } else if let ollamaError = error as? OllamaProviderError, ollamaError == .imageEncodingFailed {
                    userMessage = DexterUserFacingErrorMessage.forScreenAnalysisFailure()
                } else {
                    userMessage = DexterUserFacingErrorMessage.forCompanionModelError(error)
                }
                if !userMessage.isEmpty {
                    dexterChatErrorMessage = userMessage
                    dexterVoiceCoordinator.recordAssistantResponse(userMessage)
                    appendDexterAssistantChatMessage(userMessage, isError: true)
                    dexterVoiceCoordinator.resetStreamingResponseText()
                    dexterVoiceCoordinator.transitionToIdle()
                }
                if error is DexterModelRequestTimeoutError
                    || error is DexterContextAssemblyTimeoutError
                    || error is DexterSpeechToTextTimeoutError {
                    turnOutcome = .timeout
                } else {
                    turnOutcome = .error
                }
            }
        }

        userTurnController.setResponseTask(responseTask)
    }

    /// If the cursor is in transient mode (user toggled "Show Dexter" off),
    /// waits for TTS playback and any pointing animation to finish, then
    /// fades out the overlay after a 1-second pause. Cancelled automatically
    /// if the user starts another push-to-talk interaction.
    #if DEBUG
    private func updateDevelopmentContextInspectorIfNeeded(from context: DexterContext) {
        developmentContextInspectorSnapshot = dexterOrchestrator.developmentContextInspectorSnapshotIfEnabled(for: context)
    }
    #else
    private func updateDevelopmentContextInspectorIfNeeded(from context: DexterContext) {}
    #endif

    private func scheduleTransientHideIfNeeded() {
        guard !isDexterCursorEnabled && isOverlayVisible else { return }

        transientHideTask?.cancel()
        transientHideTask = Task {
            // Wait for TTS audio to finish playing
            while dexterSpokenResponseService.isSpeaking {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Wait for pointing animation to finish (location is cleared
            // when the buddy flies back to the cursor)
            while detectedElementScreenLocation != nil {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Pause 1s after everything finishes, then fade out
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            dexterTeachingOverlayStore.dismiss(reason: "overlay_hidden")
            overlayWindowManager.fadeOutAndHideOverlay()
            isOverlayVisible = false
        }
    }

    private func updateTeachingOverlayAfterModelTurn(
        orchestratorResponse: DexterOrchestratorModelResponse,
        parseResult: PointingParseResult,
        globalTargetPoint: CGPoint?,
        targetDisplayFrame: CGRect?
    ) {
        let activeTeachingSession = dexterOrchestrator.teachingSessionStore.activeSession
        let pointSession = activePointInvokeSession
        let normalizedUserMessage = orchestratorResponse.context.userMessage.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let isPointerTeachTurn = DexterPointerControlWorkflow.matchesPointerTeachIntent(
            normalizedUserMessage: normalizedUserMessage
        )
        let resolvedGlobalTarget = globalTargetPoint
            ?? pointSession?.pointerLocationInScreenSpace
        let resolvedDisplayFrame = targetDisplayFrame
            ?? pointSession.flatMap {
                DexterPointAskHighlightPlanner.displayFrameContaining(
                    pointInScreenSpace: $0.pointerLocationInScreenSpace
                )
            }
        let resolvedElementLabel = parseResult.elementLabel
            ?? pointSession?.userFacingSemanticTargetLabel
            ?? pointSession?.pointerSemanticTarget?.confirmationLabel

        let shouldShowTeachingAnnotations =
            activeTeachingSession != nil
            || parseResult.coordinate != nil
            || pointSession != nil
            || isPointerTeachTurn
            || orchestratorResponse.responseMode == .teach
            || orchestratorResponse.responseMode == .explain
            || orchestratorResponse.responseMode == .guide
            || orchestratorResponse.responseMode == .troubleshoot

        if shouldShowTeachingAnnotations && !overlayWindowManager.isShowingOverlay() {
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        }

        dexterTeachingOverlayStore.presentFromModelTurn(
            targetGlobalPoint: resolvedGlobalTarget,
            targetDisplayFrame: resolvedDisplayFrame,
            elementLabel: resolvedElementLabel,
            pointerGlobalPoint: pointSession?.pointerLocationInScreenSpace
                ?? lastDexterContextSnapshot?.pointerLocationInScreenSpace,
            teachingSession: activeTeachingSession,
            shouldShowTeachingAnnotations: shouldShowTeachingAnnotations
        )
    }

    // MARK: - Point Tag Parsing

    /// Result of parsing a [POINT:...] tag from Claude's response.
    struct PointingParseResult {
        /// The response text with the [POINT:...] tag removed — this is what gets spoken.
        let spokenText: String
        /// The parsed pixel coordinate, or nil if Claude said "none" or no tag was found.
        let coordinate: CGPoint?
        /// Short label describing the element (e.g. "run button"), or "none".
        let elementLabel: String?
        /// Which screen the coordinate refers to (1-based), or nil to default to cursor screen.
        let screenNumber: Int?
    }

    /// Parses a [POINT:x,y:label:screenN] or [POINT:none] tag from the end of Claude's response.
    /// Returns the spoken text (tag removed) and the optional coordinate + label + screen number.
    static func parsePointingCoordinates(from responseText: String) -> PointingParseResult {
        // Match [POINT:none] or [POINT:123,456:label] or [POINT:123,456:label:screen2]
        let pattern = #"\[POINT:(?:none|(\d+)\s*,\s*(\d+)(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?)\]\s*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)) else {
            // No tag found at all
            return PointingParseResult(spokenText: responseText, coordinate: nil, elementLabel: nil, screenNumber: nil)
        }

        // Remove the tag from the spoken text
        let tagRange = Range(match.range, in: responseText)!
        let spokenText = String(responseText[..<tagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's [POINT:none]
        guard match.numberOfRanges >= 3,
              let xRange = Range(match.range(at: 1), in: responseText),
              let yRange = Range(match.range(at: 2), in: responseText),
              let x = Double(responseText[xRange]),
              let y = Double(responseText[yRange]) else {
            return PointingParseResult(spokenText: spokenText, coordinate: nil, elementLabel: "none", screenNumber: nil)
        }

        var elementLabel: String? = nil
        if match.numberOfRanges >= 4, let labelRange = Range(match.range(at: 3), in: responseText) {
            elementLabel = String(responseText[labelRange]).trimmingCharacters(in: .whitespaces)
        }

        var screenNumber: Int? = nil
        if match.numberOfRanges >= 5, let screenRange = Range(match.range(at: 4), in: responseText) {
            screenNumber = Int(responseText[screenRange])
        }

        return PointingParseResult(
            spokenText: spokenText,
            coordinate: CGPoint(x: x, y: y),
            elementLabel: elementLabel,
            screenNumber: screenNumber
        )
    }

    // MARK: - Onboarding

    func prepareFirstRunOnboardingStep(_ step: DexterFirstRunOnboardingStep) {
        guard !hasCompletedOnboarding else { return }
    }

    func completeFirstRunProductOnboardingAndOpenHome() {
        finalizeFirstRunOnboardingProfileIfNeeded()
        firstRunOnboardingStore.markFinished()
        hasCompletedOnboarding = true
        interactiveOnboardingStore.markCompleted()
        interactiveOnboardingStore.resetToInactive()
        stopOnboardingMusic()

        if let archetype = firstRunOnboardingStore.profileDraft.archetype {
            pendingOnboardingFirstSuggestionPrompt = archetype.firstRunSuggestionPrompt
        }
        pendingOnboardingComposerPlaceholder = "What do you want to do?"
        DexterAnalytics.trackOnboardingCompleted(skipped: false)

        finishFirstRunOnboardingNavigation(openComposer: true)
    }

    private func finishFirstRunOnboardingNavigation(openComposer: Bool) {
        if openComposer {
            shouldFocusHomeComposerAfterOnboarding = true
        }
        NotificationCenter.default.post(name: .dexterFirstRunOnboardingDidFinish, object: nil)
        NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
        NotificationCenter.default.post(name: .dexterHomeFocusChat, object: nil)
    }

    private func ensureCompanionOverlayVisibleForFirstRunInteraction() {
        guard !isOverlayVisible else { return }
        overlayWindowManager.hasShownOverlayBefore = true
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    private func registerFirstRunProgressAfterSuccessfulTurn(source: DexterUserInputChannel) {
        _ = source
    }

    private func registerFirstRunPointCaptureIfNeeded(session: DexterPointInvokeSession) {
        _ = session
    }

    /// Called by BlueCursorView after the short welcome bubble — starts experiential onboarding.
    func setupOnboardingVideo() {
        showOnboardingVideo = false
        onboardingVideoOpacity = 0.0
        tearDownOnboardingVideo()

        DexterAnalytics.trackOnboardingDemoTriggered()
        if !interactiveOnboardingStore.isActive {
            interactiveOnboardingStore.beginInteractiveOnboarding()
        }
        syncInteractiveOnboardingOverlayPrompt()
        DexterAnalytics.trackOnboardingVideoCompleted()
    }

    func syncInteractiveOnboardingOverlayPrompt() {
        guard interactiveOnboardingStore.isActive else {
            showOnboardingPrompt = false
            onboardingPromptText = ""
            onboardingPromptOpacity = 0.0
            return
        }

        let prompt = interactiveOnboardingStore.overlayPrompt
        onboardingPromptText = prompt
        showOnboardingPrompt = !prompt.isEmpty
        onboardingPromptOpacity = prompt.isEmpty ? 0.0 : 1.0

        if interactiveOnboardingStore.phase == .finale, !interactiveOnboardingFinaleCompletionScheduled {
            interactiveOnboardingFinaleCompletionScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                self?.completeInteractiveOnboardingIfNeeded()
            }
        }
    }

    private func completeInteractiveOnboardingIfNeeded() {
        guard interactiveOnboardingStore.phase == .finale else { return }
        interactiveOnboardingStore.markCompleted()
        hasCompletedOnboarding = true
        stopOnboardingMusic()
        withAnimation(.easeOut(duration: 0.35)) {
            onboardingPromptOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showOnboardingPrompt = false
            self?.onboardingPromptText = ""
        }
    }

    @MainActor
    private func processInteractiveOnboardingAfterModelTurn(
        userTranscript: String,
        orchestratorResponse: DexterOrchestratorModelResponse
    ) async -> DexterTurnOutcome? {
        guard interactiveOnboardingStore.isActive else { return nil }
        refreshActionConfirmationPresentation()

        switch interactiveOnboardingStore.phase {
        case .awaitingExplainQuestion:
            guard activePointInvokeSession != nil else { return nil }
            guard DexterInteractiveOnboardingPolicy.isLikelyExplainUtterance(userTranscript) else { return nil }
            guard !orchestratorResponse.fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            interactiveOnboardingStore.registerExplainTurnCompletedIfNeeded()
            syncInteractiveOnboardingOverlayPrompt()
        case .awaitingActionRequest:
            guard DexterInteractiveOnboardingPolicy.isLikelyActionUtterance(userTranscript) else { return nil }
            if orchestratorResponse.responseMode == .act {
                interactiveOnboardingStore.registerActionRequestStartedIfNeeded()
                syncInteractiveOnboardingOverlayPrompt()
            }
            if dexterOrchestrator.actionConfirmationPresentation() != nil,
               let pendingAction = dexterOrchestrator.lastTypedAction,
               DexterInteractiveOnboardingPolicy.shouldAutoApproveOnboardingAction(action: pendingAction) {
                if let approvalOutcome = await approvePendingActionConfirmationAndWait() {
                    return DexterTurnOutcomeResolver.resolveAfterApprovedActionExecution(outcome: approvalOutcome)
                }
            } else if let completedAction = dexterOrchestrator.lastTypedAction,
                      completedAction.state == .completed {
                processInteractiveOnboardingAfterVerifiedAction(action: completedAction)
            }
        case .awaitingActionOutcome:
            if let completedAction = dexterOrchestrator.lastTypedAction,
               completedAction.state == .completed {
                processInteractiveOnboardingAfterVerifiedAction(action: completedAction)
            }
        default:
            break
        }
        return nil
    }

    private func processInteractiveOnboardingAfterVerifiedAction(action: DexterAction) {
        guard interactiveOnboardingStore.isActive else { return }
        guard action.state == .completed else { return }
        guard action.type == .openApplication else { return }
        guard DexterInteractiveOnboardingPolicy.shouldAutoApproveOnboardingAction(action: action) else { return }

        interactiveOnboardingStore.registerVerifiedActionCompletedIfNeeded()
        syncInteractiveOnboardingOverlayPrompt()
    }

    func tearDownOnboardingVideo() {
        showOnboardingVideo = false
        if let timeObserver = onboardingDemoTimeObserver {
            onboardingVideoPlayer?.removeTimeObserver(timeObserver)
            onboardingDemoTimeObserver = nil
        }
        onboardingVideoPlayer?.pause()
        onboardingVideoPlayer = nil
        if let observer = onboardingVideoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingVideoEndObserver = nil
        }
    }

}
