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
        case .starting, .processing:
            return .thinking
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
    let overlayWindowManager = OverlayWindowManager()
    // Response text is now displayed inline on the cursor overlay via
    // streamingResponseText, so no separate response overlay manager is needed.

    /// Base URL for the Cloudflare Worker proxy. All API requests route
    /// through this so keys never ship in the app binary.
    private static var workerBaseURL: String {
        DexterWorkerProxyClient.workerBaseURL
    }

    let dexterDemonstrationPhaseStore = DexterDemonstrationPhaseStore()

    private let dexterDemonstrationSessionStore = DexterDemonstrationSessionStore()

    let ollamaAIProvider = OllamaProvider()

    var dexterAIProvider: AIProvider {
        ollamaAIProvider
    }

    private lazy var dexterOrchestrator: DexterOrchestrator = {
        DexterOrchestratorFactory.makeDefault(
            ollamaProvider: ollamaAIProvider,
            demonstrationPhaseStore: dexterDemonstrationPhaseStore,
            demonstrationSessionStore: dexterDemonstrationSessionStore
        )
    }()

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
    private var currentResponseTask: Task<Void, Never>?

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
    @Published private(set) var dexterSessionExchangeCount: Int = 0
    @Published private(set) var dexterActiveTaskDescription: String?
    @Published private(set) var dexterWorkflowContextSummary: String?
    @Published private(set) var panelLastActionSummary: String?

    @Published private(set) var dexterChatMessages: [DexterChatMessage] = []
    @Published private(set) var dexterRecentConversations: [DexterRecentConversationSummary] = []
    @Published private(set) var dexterChatErrorMessage: String?
    @Published private(set) var dexterSpokenResponseErrorMessage: String?
    var pendingMainWindowDestination: DexterMainWindowDestination = .chat

    let openClawGatewayHealthMonitor = OpenClawGatewayHealthMonitor.shared

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
        }
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
        lastTranscript = trimmedMessage
        appendDexterUserChatMessage(trimmedMessage)
        DexterAnalytics.trackUserMessageSent(transcript: trimmedMessage)
        sendUserMessageToDexter(trimmedMessage, source: .typedText)
    }

    func startNewDexterConversation() {
        archiveCurrentDexterConversationIfNeeded()
        clearDexterSessionMemory()
        dexterChatMessages = []
        dexterChatErrorMessage = nil
        dexterVoiceCoordinator.resetStreamingResponseText()
        clearActivePointInvokeSession()
    }

    func openRecentDexterConversation(_ conversation: DexterRecentConversationSummary) {
        guard let archivedMessages = loadArchivedDexterConversationMessages(conversationId: conversation.id) else {
            return
        }
        dexterChatMessages = archivedMessages
        dexterChatErrorMessage = nil
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
        dexterChatMessages.append(DexterChatMessage(role: .user, text: text))
    }

    private func appendDexterAssistantChatMessage(_ text: String, isError: Bool = false) {
        dexterChatMessages.append(
            DexterChatMessage(role: .assistant, text: text, isError: isError)
        )
    }

    private func archiveCurrentDexterConversationIfNeeded() {
        guard !dexterChatMessages.isEmpty else { return }
        guard let titleMessage = dexterChatMessages.first(where: { $0.role == .user }) else { return }

        let conversationId = UUID()
        let title = String(titleMessage.text.prefix(56))
        let summary = DexterRecentConversationSummary(
            id: conversationId,
            title: title,
            lastUpdated: Date()
        )

        saveArchivedDexterConversationMessages(conversationId: conversationId, messages: dexterChatMessages)

        var updatedRecents = dexterRecentConversations.filter { $0.title != summary.title }
        updatedRecents.insert(summary, at: 0)
        dexterRecentConversations = Array(updatedRecents.prefix(8))
        persistDexterRecentConversations()
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
        dexterPersistentMemoryEntries = memoryStore.allPersistentEntries()
        dexterSessionExchangeCount = memoryStore.sessionExchangeCount
        dexterActiveTaskDescription = memoryStore.activeTaskDescription
        dexterWorkflowContextSummary = memoryStore.workflowContext?.summary
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

    func approvePendingActionConfirmation() {
        pendingActionApprovalTask?.cancel()
        pendingActionApprovalTask = Task {
            dexterDemonstrationPhaseStore.transition(to: .acting, detail: "Running approved action")
            let outcome = await dexterOrchestrator.approvePendingActionConfirmation()
            guard !Task.isCancelled else { return }
            refreshActionConfirmationPresentation()
            guard let outcome else { return }
            panelLastActionSummary = outcome.verificationReport?.summary ?? outcome.spokenSummary
            dexterVoiceCoordinator.recordAssistantResponse(outcome.spokenSummary)
            appendDexterAssistantChatMessage(outcome.spokenSummary)
            dexterVoiceCoordinator.resetStreamingResponseText()
            let spokenText = outcome.spokenSummary
            if !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               dexterVoiceCoordinator.voiceSettings.isSpokenResponsesEnabled {
                dexterVoiceCoordinator.transitionToSpeaking()
                do {
                    try await dexterSpokenResponseService.speakAssistantResponse(spokenText)
                } catch {
                    DexterAnalytics.trackTTSError(error: error.localizedDescription)
                    dexterSpokenResponseErrorMessage = DexterUserFacingErrorMessage.forTextToSpeechError(error)
                }
            }
        }
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
        refreshAllPermissions(caller: "CompanionManager.start", emitVerbosePermissionDiagnostics: true)
        print("🔑 Dexter start — accessibility: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission), mic: \(hasMicrophonePermission), screenContent: \(hasScreenContentPermission), onboarded: \(hasCompletedOnboarding)")
        startPermissionPolling()
        bindDemonstrationPhaseStore()
        bindDexterVoiceCoordinator()
        bindAudioPowerLevel()
        bindMicrophoneRuntimeState()
        bindSpeechToTextErrorPresentation()
        bindShortcutTransitions()
        bindPointInvokeShortcut()
        // Eagerly warm up the model provider TLS handshake before onboarding interactions.
        dexterOrchestrator.warmUpModelConnectionIfNeeded()
        loadDexterRecentConversationsFromDisk()
        rebuildDexterChatMessagesFromSessionMemory()
        refreshOllamaConnectionStatus()
        refreshOpenClawGatewayConnection()
        refreshDexterScreenContextUIState()
        promptForMicrophoneIfNotDetermined()
        runScreenCaptureCapabilityProbeIfNeeded()

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
        // Post notification so the panel manager can dismiss the panel
        NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)

        // Mark onboarding as completed so the Start button won't appear
        // again on future launches — the cursor will auto-show instead
        hasCompletedOnboarding = true

        DexterAnalytics.trackOnboardingStarted()

        // Play Besaid theme at 60% volume, fade out after 1m 30s
        startOnboardingMusic()

        // Show the overlay for the first time — isFirstAppearance triggers
        // the welcome animation and onboarding video
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    /// Replays the onboarding experience from the "Watch Onboarding Again"
    /// footer link. Same flow as triggerOnboarding but the cursor overlay
    /// is already visible so we just restart the welcome animation and video.
    func replayOnboarding() {
        NotificationCenter.default.post(name: .dexterDismissPanel, object: nil)
        DexterAnalytics.trackOnboardingReplayed()
        startOnboardingMusic()
        // Tear down any existing overlays and recreate with isFirstAppearance = true
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
        overlayWindowManager.hideOverlay()
        transientHideTask?.cancel()

        currentResponseTask?.cancel()
        currentResponseTask = nil
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
                guard let speechToTextErrorMessage, !speechToTextErrorMessage.isEmpty else { return }
                guard !self.buddyDictationManager.isActivelyRecordingAudio else { return }
                self.dexterChatErrorMessage = speechToTextErrorMessage
            }
            .store(in: &microphoneRuntimeStateCancellables)
    }

    private func bindDemonstrationPhaseStore() {
        demonstrationPhaseForwardCancellable = dexterDemonstrationPhaseStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
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
                if interactionState == .idle && self.currentResponseTask == nil {
                    self.scheduleTransientHideIfNeeded()
                }
            }
            .store(in: &voiceInteractionStateCancellables)
    }

    private var voiceInteractionStateCancellables = Set<AnyCancellable>()

    private func cancelActiveDexterVoiceInteraction() {
        currentResponseTask?.cancel()
        pendingActionApprovalTask?.cancel()
        dexterSpokenResponseService.stopSpeaking()
        dexterVoiceCoordinator.handleUserInterruption()
        Task {
            await dexterOrchestrator.cancelInFlightComputerActionIfNeeded()
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

        Task {
            let session = await dexterOrchestrator.preparePointInvokeSession(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                hasPersistedScreenContentGrant: hasScreenContentPermission
            )

            activePointInvokeSession = session
            lastDexterContextSnapshot = session.contextSnapshot
            isPreparingPointInvokeSession = false

            if session.contextSnapshot.screenCaptureAvailability == .permissionMissing {
                dexterScreenContextUIState = .permissionRequired
            } else if session.screenCaptureSnapshots.isEmpty {
                dexterScreenContextUIState = .unavailable
            } else {
                dexterScreenContextUIState = .ready
            }
        }
    }

    private func dexterModelGenerationOptions(forUserMessage userMessage: String) -> DexterModelGenerationOptions {
        if let activePointInvokeSession {
            return DexterModelGenerationOptions(
                screenCaptureOverride: activePointInvokeSession.screenCaptureSnapshots.isEmpty
                    ? nil
                    : activePointInvokeSession.screenCaptureSnapshots,
                includeSessionConversationHistory: true,
                hasPersistedScreenContentGrant: hasScreenContentPermission,
                pointerLocationInScreenSpaceOverride: activePointInvokeSession.pointerLocationInScreenSpace,
                usePointAtContextRelevancePlan: true
            )
        }

        return DexterModelGenerationOptions(
            hasPersistedScreenContentGrant: hasScreenContentPermission
        )
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

        pendingKeyboardShortcutStartTask?.cancel()
        pendingKeyboardShortcutStartTask = Task {
            await buddyDictationManager.startPushToTalkFromKeyboardShortcut(
                currentDraftText: "",
                updateDraftText: { _ in
                    // Partial transcripts are hidden (waveform-only UI)
                },
                submitDraftText: { [weak self] finalTranscript in
                    DexterMicDiagnosticLog.log("transcript received (\(finalTranscript.count) characters)")
                    DexterDiagnosticLog.stt("transcript received (\(finalTranscript.count) characters)")
                    self?.lastTranscript = finalTranscript
                    self?.appendDexterUserChatMessage(finalTranscript)
                    DexterAnalytics.trackUserMessageSent(transcript: finalTranscript)
                    DexterDiagnosticLog.voice("transcript sent to orchestrator")
                    self?.sendUserMessageToDexter(finalTranscript, source: .pushToTalkTranscript)
                }
            )
        }
    }

    private func endPushToTalkSession() {
        DexterAnalytics.trackPushToTalkReleased()
        buddyDictationManager.handleKeyboardShortcutReleased()
        pendingKeyboardShortcutStartTask = nil
    }

    // MARK: - Dexter Voice response pipeline

    /// Speech-to-text (push-to-talk) or typed text → streamed model response → optional TTS.
    private func sendUserMessageToDexter(_ transcript: String, source: DexterVoiceUserMessageSource) {
        cancelActiveDexterVoiceInteraction()

        currentResponseTask = Task {
            _ = DexterTurnTrace.beginTurn()
            var turnOutcome: DexterTurnOutcome?
            let screenRecordingPreflightGranted = CGPreflightScreenCaptureAccess()
            let userRequestedScreenContext = activePointInvokeSession != nil
                || DexterContextRelevancePlanner.shouldRequestScreenCapture(forUserMessage: transcript)

            defer {
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
                DexterTurnTrace.finish(outcome: turnOutcome ?? .error)
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

            DexterTurnTrace.log("USER REQUEST: \(transcript)")
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

            let resolvedSystemPrompt = DexterAISystemPrompt.companionSystemPrompt
                + (source == .pushToTalkTranscript ? DexterAISystemPrompt.voiceResponseSupplement : "")

            do {
                let orchestratorResponse = try await dexterOrchestrator.generateModelResponse(
                    userTranscript: transcript,
                    systemPrompt: resolvedSystemPrompt,
                    options: dexterModelGenerationOptions(forUserMessage: transcript),
                    onTextChunk: { [weak self] chunk in
                        self?.dexterVoiceCoordinator.appendStreamingResponseChunk(chunk)
                    }
                )

                DexterTurnTrace.log("orchestrator finished")
                DexterDiagnosticLog.model("model response received")

                guard !Task.isCancelled else {
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
                    DexterAnalytics.trackElementPointed(elementLabel: parseResult.elementLabel)
                    print("🎯 Element pointing: (\(Int(pointCoordinate.x)), \(Int(pointCoordinate.y))) → \"\(parseResult.elementLabel ?? "element")\"")
                } else {
                    print("🎯 Element pointing: \(parseResult.elementLabel ?? "no element")")
                }

                dexterOrchestrator.recordConversationExchange(
                    userTranscript: transcript,
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
                turnOutcome = .success

                if !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   dexterVoiceCoordinator.voiceSettings.isSpokenResponsesEnabled {
                    dexterVoiceCoordinator.transitionToSpeaking()
                    do {
                        try await dexterSpokenResponseService.speakAssistantResponse(spokenText)
                    } catch is CancellationError {
                        DexterDiagnosticLog.tts("playback cancelled")
                    } catch {
                        DexterAnalytics.trackTTSError(error: error.localizedDescription)
                        DexterDiagnosticLog.tts("playback failed")
                        let spokenErrorMessage = DexterUserFacingErrorMessage.forTextToSpeechError(error)
                        dexterSpokenResponseErrorMessage = spokenErrorMessage
                    }
                    if dexterVoiceCoordinator.interactionState == .speaking {
                        dexterVoiceCoordinator.transitionToIdle()
                    }
                }
            } catch is CancellationError {
                dexterDemonstrationPhaseStore.reset()
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
            overlayWindowManager.fadeOutAndHideOverlay()
            isOverlayVisible = false
        }
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

    /// Runs the interactive onboarding sequence after the welcome message.
    /// Called by BlueCursorView when onboarding starts.
    func setupOnboardingVideo() {
        showOnboardingVideo = false
        onboardingVideoOpacity = 0.0
        tearDownOnboardingVideo()

        DexterAnalytics.trackOnboardingDemoTriggered()
        performOnboardingDemoInteraction()

        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) { [weak self] in
            guard let self else { return }
            DexterAnalytics.trackOnboardingVideoCompleted()
            self.startOnboardingPromptStream()
        }
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

    private func startOnboardingPromptStream() {
        let message = "press control + option and say hi to dexter"
        onboardingPromptText = ""
        showOnboardingPrompt = true
        onboardingPromptOpacity = 0.0

        withAnimation(.easeIn(duration: 0.4)) {
            onboardingPromptOpacity = 1.0
        }

        var currentIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard currentIndex < message.count else {
                timer.invalidate()
                // Auto-dismiss after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    guard self.showOnboardingPrompt else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.onboardingPromptOpacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.showOnboardingPrompt = false
                        self.onboardingPromptText = ""
                    }
                }
                return
            }
            let index = message.index(message.startIndex, offsetBy: currentIndex)
            self.onboardingPromptText.append(message[index])
            currentIndex += 1
        }
    }

    /// Gradually raises an AVPlayer's volume from its current level to the
    /// target over the specified duration, creating a smooth audio fade-in.
    private func fadeInVideoAudio(player: AVPlayer, targetVolume: Float, duration: Double) {
        let steps = 20
        let stepInterval = duration / Double(steps)
        let volumeIncrement = (targetVolume - player.volume) / Float(steps)
        var stepsRemaining = steps

        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            stepsRemaining -= 1
            player.volume += volumeIncrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.volume = targetVolume
            }
        }
    }

    // MARK: - Onboarding Demo Interaction

    private static let onboardingDemoSystemPrompt = """
    you're dexter, a small blue cursor buddy living on the user's screen. you're showing off during onboarding — look at their screen and find ONE specific, concrete thing to point at. pick something with a clear name or identity: a specific app icon (say its name), a specific word or phrase of text you can read, a specific filename, a specific button label, a specific tab title, a specific image you can describe. do NOT point at vague things like "a window" or "some text" — be specific about exactly what you see.

    make a short quirky 3-6 word observation about the specific thing you picked — something fun, playful, or curious that shows you actually read/recognized it. no emojis ever. NEVER quote or repeat text you see on screen — just react to it. keep it to 6 words max, no exceptions.

    CRITICAL COORDINATE RULE: you MUST only pick elements near the CENTER of the screen. your x coordinate must be between 20%-80% of the image width. your y coordinate must be between 20%-80% of the image height. do NOT pick anything in the top 20%, bottom 20%, left 20%, or right 20% of the screen. no menu bar items, no dock icons, no sidebar items, no items near any edge. only things clearly in the middle area of the screen. if the only interesting things are near the edges, pick something boring in the center instead.

    respond with ONLY your short comment followed by the coordinate tag. nothing else. all lowercase.

    format: your comment [POINT:x,y:label]

    the screenshot images are labeled with their pixel dimensions. use those dimensions as the coordinate space. origin (0,0) is top-left. x increases rightward, y increases downward.
    """

    /// Captures a screenshot and asks Claude to find something interesting to
    /// point at, then triggers the buddy's flight animation. Used during
    /// onboarding to demo the pointing feature while the intro video plays.
    func performOnboardingDemoInteraction() {
        // Don't interrupt an active voice response
        let interactionState = dexterVoiceCoordinator.interactionState
        guard interactionState == .idle || interactionState == .speaking else { return }

        Task {
            do {
                let allScreenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()

                guard let cursorScreenCapture = allScreenCaptures.first(where: { $0.isCursorScreen }) else {
                    print("🎯 Onboarding demo: no cursor screen found")
                    return
                }

                let cursorScreenSnapshot = DexterScreenCaptureSnapshot(companionScreenCapture: cursorScreenCapture)
                let orchestratorResponse = try await dexterOrchestrator.generateModelResponse(
                    userTranscript: "look around my screen and find something interesting to point at",
                    systemPrompt: Self.onboardingDemoSystemPrompt,
                    options: DexterModelGenerationOptions(
                        screenCaptureOverride: [cursorScreenSnapshot],
                        includeSessionConversationHistory: false,
                        hasPersistedScreenContentGrant: hasScreenContentPermission
                    ),
                    onTextChunk: { _ in }
                )

                let fullResponseText = orchestratorResponse.fullResponseText
                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)

                guard let pointCoordinate = parseResult.coordinate else {
                    print("🎯 Onboarding demo: no element to point at")
                    return
                }

                let screenshotWidth = CGFloat(cursorScreenCapture.screenshotWidthInPixels)
                let screenshotHeight = CGFloat(cursorScreenCapture.screenshotHeightInPixels)
                let displayWidth = CGFloat(cursorScreenCapture.displayWidthInPoints)
                let displayHeight = CGFloat(cursorScreenCapture.displayHeightInPoints)
                let displayFrame = cursorScreenCapture.displayFrame

                let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
                let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))
                let displayLocalX = clampedX * (displayWidth / screenshotWidth)
                let displayLocalY = clampedY * (displayHeight / screenshotHeight)
                let appKitY = displayHeight - displayLocalY
                let globalLocation = CGPoint(
                    x: displayLocalX + displayFrame.origin.x,
                    y: appKitY + displayFrame.origin.y
                )

                // Set custom bubble text so the pointing animation uses Claude's
                // comment instead of a random phrase
                detectedElementBubbleText = parseResult.spokenText
                detectedElementScreenLocation = globalLocation
                detectedElementDisplayFrame = displayFrame
                print("🎯 Onboarding demo: pointing at \"\(parseResult.elementLabel ?? "element")\" — \"\(parseResult.spokenText)\"")
            } catch {
                print("⚠️ Onboarding demo error: \(error)")
            }
        }
    }
}
