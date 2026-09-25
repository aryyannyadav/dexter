//
//  BuddyDictationManager.swift
//  leanring-buddy
//
//  Shared push-to-talk dictation manager for the help chat and brainstorm buddy.
//  Captures microphone audio with AVAudioEngine, routes it into the active
//  transcription provider, and hands the final draft back to the active input bar.
//

import AppKit
import AVFoundation
import Combine
import Foundation
import Speech

enum BuddyPushToTalkShortcut {
    enum ShortcutOption {
        case shiftFunction
        case controlOption
        case shiftControl
        case controlOptionSpace
        case shiftControlSpace

        var displayText: String {
            switch self {
            case .shiftFunction:
                return "shift + fn"
            case .controlOption:
                return "ctrl + option"
            case .shiftControl:
                return "shift + control"
            case .controlOptionSpace:
                return "ctrl + option + space"
            case .shiftControlSpace:
                return "shift + control + space"
            }
        }

        var keyCapsuleLabels: [String] {
            switch self {
            case .shiftFunction:
                return ["shift", "fn"]
            case .controlOption:
                return ["ctrl", "option"]
            case .shiftControl:
                return ["shift", "control"]
            case .controlOptionSpace:
                return ["ctrl", "option", "space"]
            case .shiftControlSpace:
                return ["shift", "control", "space"]
            }
        }

        fileprivate var modifierOnlyFlags: NSEvent.ModifierFlags? {
            switch self {
            case .shiftFunction:
                return [.shift, .function]
            case .controlOption:
                return [.control, .option]
            case .shiftControl:
                return [.shift, .control]
            case .controlOptionSpace, .shiftControlSpace:
                return nil
            }
        }

        fileprivate var spaceShortcutModifierFlags: NSEvent.ModifierFlags? {
            switch self {
            case .shiftFunction:
                return nil
            case .controlOption:
                return nil
            case .shiftControl:
                return nil
            case .controlOptionSpace:
                return [.control, .option]
            case .shiftControlSpace:
                return [.shift, .control]
            }
        }
    }

    enum ShortcutTransition {
        case none
        case pressed
        case released
    }

    private enum ShortcutEventType {
        case flagsChanged
        case keyDown
        case keyUp
    }

    static var currentShortcutOption: ShortcutOption {
        DexterShortcutSettingsStore.shared.pushToTalkShortcutOption
    }

    static let pushToTalkKeyCode: UInt16 = 49 // Space
    static var pushToTalkDisplayText: String { currentShortcutOption.displayText }
    static var pushToTalkTooltipText: String { "push to talk (\(pushToTalkDisplayText))" }

    static func shortcutTransition(
        for event: NSEvent,
        wasShortcutPreviouslyPressed: Bool
    ) -> ShortcutTransition {
        guard let shortcutEventType = shortcutEventType(for: event.type) else { return .none }

        return shortcutTransition(
            for: shortcutEventType,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags.intersection(.deviceIndependentFlagsMask),
            wasShortcutPreviouslyPressed: wasShortcutPreviouslyPressed
        )
    }

    static func shortcutTransition(
        for eventType: CGEventType,
        keyCode: UInt16,
        modifierFlagsRawValue: UInt64,
        wasShortcutPreviouslyPressed: Bool
    ) -> ShortcutTransition {
        guard let shortcutEventType = shortcutEventType(for: eventType) else { return .none }

        return shortcutTransition(
            for: shortcutEventType,
            keyCode: keyCode,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(modifierFlagsRawValue))
                .intersection(.deviceIndependentFlagsMask),
            wasShortcutPreviouslyPressed: wasShortcutPreviouslyPressed
        )
    }

    private static func shortcutEventType(for eventType: NSEvent.EventType) -> ShortcutEventType? {
        switch eventType {
        case .flagsChanged:
            return .flagsChanged
        case .keyDown:
            return .keyDown
        case .keyUp:
            return .keyUp
        default:
            return nil
        }
    }

    private static func shortcutEventType(for eventType: CGEventType) -> ShortcutEventType? {
        switch eventType {
        case .flagsChanged:
            return .flagsChanged
        case .keyDown:
            return .keyDown
        case .keyUp:
            return .keyUp
        default:
            return nil
        }
    }

    private static func shortcutTransition(
        for shortcutEventType: ShortcutEventType,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        wasShortcutPreviouslyPressed: Bool
    ) -> ShortcutTransition {
        if let modifierOnlyFlags = currentShortcutOption.modifierOnlyFlags {
            guard shortcutEventType == .flagsChanged else { return .none }

            let isShortcutCurrentlyPressed = modifierFlags.contains(modifierOnlyFlags)

            if isShortcutCurrentlyPressed && !wasShortcutPreviouslyPressed {
                return .pressed
            }

            if !isShortcutCurrentlyPressed && wasShortcutPreviouslyPressed {
                return .released
            }

            return .none
        }

        guard let pushToTalkModifierFlags = currentShortcutOption.spaceShortcutModifierFlags else {
            return .none
        }

        let matchesModifierFlags = modifierFlags.isSuperset(of: pushToTalkModifierFlags)

        if shortcutEventType == .keyDown
            && keyCode == pushToTalkKeyCode
            && matchesModifierFlags
            && !wasShortcutPreviouslyPressed {
            return .pressed
        }

        if shortcutEventType == .keyUp
            && keyCode == pushToTalkKeyCode
            && wasShortcutPreviouslyPressed {
            return .released
        }

        return .none
    }
}

enum BuddyDictationPermissionProblem {
    case microphoneAccessDenied
    case speechRecognitionDenied
}

private enum BuddyDictationStartSource {
    case microphoneButton
    case keyboardShortcut
}

private struct BuddyDictationDraftCallbacks {
    let updateDraftText: (String) -> Void
    let submitDraftText: (String) -> Void
}

@MainActor
final class BuddyDictationManager: NSObject, ObservableObject {
    private static let defaultFinalTranscriptFallbackDelaySeconds: TimeInterval = 2.4
    private static let recordedAudioPowerHistoryLength = 44
    private static let recordedAudioPowerHistoryBaselineLevel: CGFloat = 0.02
    private static let recordedAudioPowerHistorySampleIntervalSeconds: TimeInterval = 0.07

    @Published private(set) var isRecordingFromMicrophoneButton = false
    @Published private(set) var isRecordingFromKeyboardShortcut = false
    @Published private(set) var isKeyboardShortcutSessionActiveOrFinalizing = false
    @Published private(set) var isFinalizingTranscript = false
    @Published private(set) var isPreparingToRecord = false
    @Published private(set) var currentAudioPowerLevel: CGFloat = 0
    @Published private(set) var microphoneHardwareInputDetected = false
    @Published private(set) var recordedAudioPowerHistory = Array(
        repeating: BuddyDictationManager.recordedAudioPowerHistoryBaselineLevel,
        count: BuddyDictationManager.recordedAudioPowerHistoryLength
    )
    @Published private(set) var microphoneButtonRecordingStartedAt: Date?
    @Published private(set) var transcriptionProviderDisplayName = ""
    @Published private(set) var lastMicrophoneErrorMessage: String?
    @Published private(set) var speechToTextErrorMessage: String?
    @Published private(set) var currentPermissionProblem: BuddyDictationPermissionProblem?

    /// Stored preference from Settings; applied when configuring the audio engine for a new session.
    var preferredMicrophoneDeviceIdentifier: String?

    var isDictationInProgress: Bool {
        isPreparingToRecord || isRecordingFromMicrophoneButton || isRecordingFromKeyboardShortcut || isFinalizingTranscript
    }

    var speechToTextReadiness: DexterSpeechToTextReadiness {
        DexterSpeechToTextStatusResolver.resolve(provider: transcriptionProvider)
    }

    var isActivelyRecordingAudio: Bool {
        isRecordingFromMicrophoneButton || isRecordingFromKeyboardShortcut
    }

    var isMicrophoneButtonActivelyRecordingAudio: Bool {
        isRecordingFromMicrophoneButton
    }

    var isMicrophoneButtonSessionBusy: Bool {
        activeStartSource == .microphoneButton
            && (isPreparingToRecord || isRecordingFromMicrophoneButton || isFinalizingTranscript)
    }

    var needsInitialPermissionPrompt: Bool {
        if transcriptionProvider.requiresSpeechRecognitionPermission {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
                || SFSpeechRecognizer.authorizationStatus() == .notDetermined
        }

        return AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
    }

    private let transcriptionProvider: any BuddyTranscriptionProvider
    private let audioEngine = AVAudioEngine()
    private var activeTranscriptionSession: (any BuddyStreamingTranscriptionSession)?
    private var activeStartSource: BuddyDictationStartSource?
    private var draftCallbacks: BuddyDictationDraftCallbacks?
    private var draftTextBeforeCurrentDictation = ""
    private var latestRecognizedText = ""
    private var shouldAutomaticallySubmitFinalDraft = false
    private var hasFinishedCurrentDictationSession = false
    private var finalizeFallbackWorkItem: DispatchWorkItem?
    private var pendingStartRequestIdentifier = UUID()
    private var contextualKeyterms: [String] = []
    private var lastRecordedAudioPowerSampleDate = Date.distantPast
    private var activePermissionRequestTask: Task<Bool, Never>?
    /// Timestamp of the last completed permission request, used to debounce
    /// rapid follow-up requests that arrive before macOS updates its cache.
    private var lastPermissionRequestCompletedAt: Date?
    private var hasLoggedNonZeroAudioSamples = false
    private var hasLoggedSTTAudioForward = false
    private var lastMicRuntimeBufferDiagnosticLogDate = Date.distantPast
    private var lastMicRawBufferDiagnosticLogDate = Date.distantPast
    private var currentMicLifecycleIdentifier: UUID?
    private var activeStartRequestIdentifier: UUID?

    override init() {
        let transcriptionProvider = BuddyTranscriptionProviderFactory.makeDefaultProvider()
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionProviderDisplayName = transcriptionProvider.displayName
        super.init()
    }

    func updateContextualKeyterms(_ contextualKeyterms: [String]) {
        self.contextualKeyterms = contextualKeyterms
    }

    func startPersistentDictationFromMicrophoneButton(
        currentDraftText: String,
        updateDraftText: @escaping (String) -> Void,
        submitDraftText: @escaping (String) -> Void
    ) async {
        await startPushToTalk(
            startSource: .microphoneButton,
            currentDraftText: currentDraftText,
            updateDraftText: updateDraftText,
            submitDraftText: submitDraftText,
            shouldAutomaticallySubmitFinalDraftOnStop: false
        )
    }

    func startPushToTalkFromKeyboardShortcut(
        currentDraftText: String,
        updateDraftText: @escaping (String) -> Void,
        submitDraftText: @escaping (String) -> Void
    ) async {
        await startPushToTalk(
            startSource: .keyboardShortcut,
            currentDraftText: currentDraftText,
            updateDraftText: updateDraftText,
            submitDraftText: submitDraftText,
            shouldAutomaticallySubmitFinalDraftOnStop: currentDraftText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
    }

    func stopPersistentDictationFromMicrophoneButton() {
        stopPushToTalk(expectedStartSource: .microphoneButton)
    }

    func stopPushToTalkFromKeyboardShortcut() {
        handleKeyboardShortcutReleased()
    }

    func handleKeyboardShortcutReleased() {
        pendingStartRequestIdentifier = UUID()

        if isPreparingToRecord && activeStartSource == nil {
            isPreparingToRecord = false
            activeTranscriptionSession?.cancel()
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            clearDictationErrorMessages()
            resetSessionState()
            return
        }

        stopPushToTalk(expectedStartSource: .keyboardShortcut)
    }

    func cancelCurrentDictation(preserveDraftText: Bool = true) {
        pendingStartRequestIdentifier = UUID()

        guard isDictationInProgress else { return }

        finalizeFallbackWorkItem?.cancel()
        finalizeFallbackWorkItem = nil

        if preserveDraftText {
            let currentDraftText = composeDraftText(withTranscribedText: latestRecognizedText)
            draftCallbacks?.updateDraftText(currentDraftText)
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        activeTranscriptionSession?.cancel()

        resetSessionState()
    }

    func requestInitialPushToTalkPermissionsIfNeeded() async {
        guard needsInitialPermissionPrompt else { return }
        guard !isDictationInProgress else { return }

        clearDictationErrorMessages()
        currentPermissionProblem = nil
        isPreparingToRecord = true

        NSApplication.shared.activate(ignoringOtherApps: true)

        do {
            try await Task.sleep(for: .milliseconds(200))
        } catch {
            // If the task is cancelled while we are waiting for macOS to bring
            // the app forward, we can safely continue into the permission check.
        }

        let hasPermissions = await requestMicrophoneAndSpeechPermissionsWithoutDuplicatePrompts()
        isPreparingToRecord = false

        if hasPermissions {
            clearDictationErrorMessages()
        }
    }

    private func startPushToTalk(
        startSource: BuddyDictationStartSource,
        currentDraftText: String,
        updateDraftText: @escaping (String) -> Void,
        submitDraftText: @escaping (String) -> Void,
        shouldAutomaticallySubmitFinalDraftOnStop: Bool
    ) async {
        guard !isDictationInProgress else { return }

        DexterMicRuntimeLog.log("START REASON=\(startSource)")
        DexterMicRuntimeLog.log("start requested")
        DexterMicDiagnosticLog.log("start requested (\(startSource))")
        print("🎙️ BuddyDictationManager: start requested (\(startSource))")

        if needsInitialPermissionPrompt {
            print("🎙️ BuddyDictationManager: requesting initial permissions")
            NSApplication.shared.activate(ignoringOtherApps: true)

            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                // If the task is cancelled while the app is being activated,
                // we can safely continue into the permission request.
            }
        }

        let startRequestIdentifier = UUID()
        pendingStartRequestIdentifier = startRequestIdentifier
        activeStartRequestIdentifier = startRequestIdentifier
        currentMicLifecycleIdentifier = startRequestIdentifier
        DexterMicLifecycleLog.startRequested(id: startRequestIdentifier)
        DexterMicLifecycleLog.startAsyncBegin(id: startRequestIdentifier)

        clearDictationErrorMessages()
        currentPermissionProblem = nil
        isPreparingToRecord = true

        guard await requestMicrophoneAndSpeechPermissionsWithoutDuplicatePrompts() else {
            print("🎙️ BuddyDictationManager: permissions missing or denied")
            isPreparingToRecord = false
            return
        }
        guard !Task.isCancelled else {
            print("🎙️ BuddyDictationManager: start cancelled (shortcut released during permission check)")
            isPreparingToRecord = false
            return
        }
        guard pendingStartRequestIdentifier == startRequestIdentifier else {
            print("🎙️ BuddyDictationManager: start request superseded")
            isPreparingToRecord = false
            clearDictationErrorMessages()
            return
        }

        draftTextBeforeCurrentDictation = currentDraftText
        latestRecognizedText = ""
        draftCallbacks = BuddyDictationDraftCallbacks(
            updateDraftText: updateDraftText,
            submitDraftText: submitDraftText
        )
        shouldAutomaticallySubmitFinalDraft = shouldAutomaticallySubmitFinalDraftOnStop
        hasFinishedCurrentDictationSession = false
        isFinalizingTranscript = false
        currentAudioPowerLevel = 0
        microphoneHardwareInputDetected = false
        hasLoggedNonZeroAudioSamples = false
        hasLoggedSTTAudioForward = false
        lastMicRuntimeBufferDiagnosticLogDate = .distantPast
        lastMicRawBufferDiagnosticLogDate = .distantPast
        recordedAudioPowerHistory = Array(
            repeating: Self.recordedAudioPowerHistoryBaselineLevel,
            count: Self.recordedAudioPowerHistoryLength
        )
        microphoneButtonRecordingStartedAt = nil
        lastRecordedAudioPowerSampleDate = .distantPast

        guard !Task.isCancelled else {
            print("🎙️ BuddyDictationManager: start cancelled (shortcut released before recording began)")
            resetSessionState()
            return
        }

        do {
            try await startRecognitionSession(lifecycleIdentifier: startRequestIdentifier)
            guard pendingStartRequestIdentifier == startRequestIdentifier else {
                print("🎙️ BuddyDictationManager: start superseded after session start")
                clearDictationErrorMessages()
                resetSessionState()
                return
            }
            guard !Task.isCancelled else {
                print("🎙️ BuddyDictationManager: start cancelled (shortcut released during session start)")
                clearDictationErrorMessages()
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
                activeTranscriptionSession?.cancel()
                resetSessionState()
                return
            }

            activeStartSource = startSource
            isRecordingFromMicrophoneButton = startSource == .microphoneButton
            isRecordingFromKeyboardShortcut = startSource == .keyboardShortcut
            isKeyboardShortcutSessionActiveOrFinalizing = startSource == .keyboardShortcut

            if startSource == .microphoneButton {
                microphoneButtonRecordingStartedAt = Date()
            }
            isPreparingToRecord = false
            DexterDiagnosticLog.permissionMic("recording started")
            print("[MIC] recording started")
            print("🎙️ BuddyDictationManager: recognition session started")
        } catch {
            isPreparingToRecord = false
            if isBenignMicrophoneCancellation(error) || pendingStartRequestIdentifier != startRequestIdentifier {
                clearDictationErrorMessages()
                print("🎙️ BuddyDictationManager: start cancelled cleanly (\(transcriptionProvider.displayName))")
                resetSessionState()
                return
            }
            speechToTextErrorMessage = DexterSpeechToTextUserFacing.presentation(for: error).detail
            print("❌ BuddyDictationManager: failed to start recognition session (\(transcriptionProvider.displayName)): \(error)")
            resetSessionState()
        }
    }

    private func stopPushToTalk(expectedStartSource: BuddyDictationStartSource) {
        DexterMicLifecycleLog.stopRequested(id: currentMicLifecycleIdentifier)
        pendingStartRequestIdentifier = UUID()

        guard activeStartSource == expectedStartSource else {
            isPreparingToRecord = false
            return
        }
        guard !isFinalizingTranscript else {
            DexterMicLifecycleLog.stopIgnored(
                id: currentMicLifecycleIdentifier,
                reason: "session already stopping"
            )
            return
        }

        print("🎙️ BuddyDictationManager: stop requested (\(expectedStartSource))")

        isRecordingFromMicrophoneButton = false
        isRecordingFromKeyboardShortcut = false
        isFinalizingTranscript = true

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard let self else { return }
            guard self.isFinalizingTranscript, !self.hasFinishedCurrentDictationSession else { return }
            DexterMicDiagnosticLog.log("STT finalize timed out")
            self.speechToTextErrorMessage = DexterSpeechToTextTimeoutError(timeoutSeconds: 45).errorDescription
            self.finishCurrentDictationSessionIfNeeded(
                shouldSubmitFinalDraft: self.shouldAutomaticallySubmitFinalDraft
            )
        }

        let finalTranscriptFallbackDelaySeconds = activeTranscriptionSession?.finalTranscriptFallbackDelaySeconds
            ?? Self.defaultFinalTranscriptFallbackDelaySeconds

        activeTranscriptionSession?.requestFinalTranscript()

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        finalizeFallbackWorkItem?.cancel()
        let shouldSubmitFinalDraftWhenFallbackTriggers = shouldAutomaticallySubmitFinalDraft
        let fallbackWorkItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.finishCurrentDictationSessionIfNeeded(
                    shouldSubmitFinalDraft: shouldSubmitFinalDraftWhenFallbackTriggers
                )
            }
        }
        finalizeFallbackWorkItem = fallbackWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + finalTranscriptFallbackDelaySeconds,
            execute: fallbackWorkItem
        )
    }

    private func startRecognitionSession(lifecycleIdentifier: UUID) async throws {
        activeTranscriptionSession?.cancel()
        activeTranscriptionSession = nil

        try startRawAudioEngineCapture(lifecycleIdentifier: lifecycleIdentifier)
        DexterMicLifecycleLog.audioStarted(id: lifecycleIdentifier)

        guard pendingStartRequestIdentifier == lifecycleIdentifier else {
            throw CancellationError()
        }

        guard transcriptionProvider.isConfigured else {
            let readiness = DexterSpeechToTextStatusResolver.resolve(provider: transcriptionProvider)
            DexterDiagnosticLog.stt("STT provider not configured: \(readiness.developerDiagnosticLine)")
            throw DexterSpeechToTextProviderUnavailableError(
                providerDisplayName: transcriptionProviderDisplayName,
                developerDetail: readiness.developerDiagnosticLine
            )
        }

        DexterMicLifecycleLog.providerOpening(id: lifecycleIdentifier)
        print("🎙️ BuddyDictationManager: opening transcription provider \(transcriptionProvider.displayName)")

        let dictationPreferences = DexterDictationSettingsStore.shared
        DexterDiagnosticLog.stt(
            "dictation preferences autoDetect=\(dictationPreferences.isAutoDetectLanguageEnabled) language=\(dictationPreferences.selectedLanguageIdentifier)"
        )

        let activeTranscriptionSession = try await transcriptionProvider.startStreamingSession(
            keyterms: buildTranscriptionKeyterms(),
            onTranscriptUpdate: { [weak self] transcriptText in
                Task { @MainActor in
                    self?.latestRecognizedText = transcriptText
                }
            },
            onFinalTranscriptReady: { [weak self] transcriptText in
                Task { @MainActor in
                    guard let self else { return }
                    self.latestRecognizedText = transcriptText

                    if self.isFinalizingTranscript {
                        self.finishCurrentDictationSessionIfNeeded(
                            shouldSubmitFinalDraft: self.shouldAutomaticallySubmitFinalDraft
                        )
                    }
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.handleRecognitionError(error)
                }
            }
        )

        guard pendingStartRequestIdentifier == lifecycleIdentifier else {
            activeTranscriptionSession.cancel()
            throw CancellationError()
        }

        self.activeTranscriptionSession = activeTranscriptionSession
        DexterMicLifecycleLog.providerReady(id: lifecycleIdentifier)
        DexterMicRuntimeLog.log("STT started (\(transcriptionProvider.displayName))")
        DexterMicDiagnosticLog.log("STT started (\(transcriptionProvider.displayName))")
    }

    private func startRawAudioEngineCapture(lifecycleIdentifier: UUID) throws {
        if let preferredMicrophoneDeviceIdentifier {
            DexterMicDiagnosticLog.log("preferred microphone device id=\(preferredMicrophoneDeviceIdentifier)")
        }

        let inputNode = audioEngine.inputNode
        DexterMicRawLog.log("input node obtained")
        DexterMicRuntimeLog.log("input node obtained")
        let inputFormat = inputNode.outputFormat(forBus: 0)
        DexterMicRawLog.log("input format=sampleRate:\(inputFormat.sampleRate) channels:\(inputFormat.channelCount)")
        DexterMicRuntimeLog.log("input format=sampleRate:\(inputFormat.sampleRate) channels:\(inputFormat.channelCount)")

        inputNode.removeTap(onBus: 0)
        DexterMicRawLog.log("installing tap")
        DexterMicRuntimeLog.log("installing tap")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            if !self.hasLoggedSTTAudioForward {
                self.hasLoggedSTTAudioForward = true
                DexterMicDiagnosticLog.log("received audio buffer size=\(buffer.frameLength) frames")
                DexterPermissionDiagnostics.logSTTAudioBufferForwarded()
            }
            self.logThrottledMicRawAudioBuffer(buffer)
            self.logThrottledMicRuntimeAudioBuffer(buffer)
            self.activeTranscriptionSession?.appendAudioBuffer(buffer)
            self.updateAudioPowerLevel(from: buffer)
        }
        DexterMicRawLog.log("tap installed")
        DexterMicRuntimeLog.log("tap installed")

        audioEngine.prepare()
        DexterMicRawLog.log("audio engine starting")
        DexterMicRuntimeLog.log("starting audio engine")
        do {
            try audioEngine.start()
            DexterMicRawLog.log("audio engine started")
            DexterMicRuntimeLog.log("audio engine started")
            DexterPermissionDiagnostics.logAudioEngineStarted()
        } catch {
            DexterMicDiagnosticLog.log("audio engine failed: \(error.localizedDescription)")
            DexterPermissionDiagnostics.logAudioEngineStartFailed(error)
            throw error
        }
    }

    private func handleRecognitionError(_ error: Error) {
        if hasFinishedCurrentDictationSession {
            return
        }

        if isFinalizingTranscript && !latestRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finishCurrentDictationSessionIfNeeded(
                shouldSubmitFinalDraft: shouldAutomaticallySubmitFinalDraft
            )
        } else {
            print("❌ Buddy dictation error (\(transcriptionProvider.displayName)): \(error)")
            speechToTextErrorMessage = DexterSpeechToTextUserFacing.presentation(for: error).detail
            cancelCurrentDictation(preserveDraftText: false)
        }
    }

    private func finishCurrentDictationSessionIfNeeded(shouldSubmitFinalDraft: Bool) {
        guard !hasFinishedCurrentDictationSession else { return }
        hasFinishedCurrentDictationSession = true

        finalizeFallbackWorkItem?.cancel()
        finalizeFallbackWorkItem = nil

        let finalDraftText = composeDraftText(withTranscribedText: latestRecognizedText)
        let finalTranscriptText = latestRecognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDraftCallbacks = draftCallbacks

        if !shouldSubmitFinalDraft && !finalDraftText.isEmpty {
            currentDraftCallbacks?.updateDraftText(finalDraftText)
        }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        activeTranscriptionSession?.cancel()

        guard shouldSubmitFinalDraft else {
            resetSessionState()
            return
        }

        guard !finalTranscriptText.isEmpty else {
            speechToTextErrorMessage = DexterSpeechToTextUserFacing
                .presentationForEmptyTranscript(providerDisplayName: transcriptionProviderDisplayName)
                .detail
            resetSessionState()
            return
        }

        DexterDiagnosticLog.stt("final transcript received: \(finalTranscriptText)")
        DexterMicRuntimeLog.log("transcript=\(finalTranscriptText)")
        DexterMicDiagnosticLog.log("transcript=\(finalTranscriptText)")
        currentDraftCallbacks?.submitDraftText(finalDraftText)
        resetSessionState()
    }

    func clearSpeechToTextErrorMessage() {
        speechToTextErrorMessage = nil
    }

    private func clearDictationErrorMessages() {
        lastMicrophoneErrorMessage = nil
        speechToTextErrorMessage = nil
    }

    private func composeDraftText(withTranscribedText transcribedText: String) -> String {
        let trimmedTranscriptText = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTranscriptText.isEmpty else {
            return draftTextBeforeCurrentDictation
        }

        let trimmedExistingDraftText = draftTextBeforeCurrentDictation
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedExistingDraftText.isEmpty else {
            return trimmedTranscriptText
        }

        if draftTextBeforeCurrentDictation.hasSuffix(" ") || draftTextBeforeCurrentDictation.hasSuffix("\n") {
            return draftTextBeforeCurrentDictation + trimmedTranscriptText
        }

        return draftTextBeforeCurrentDictation + " " + trimmedTranscriptText
    }

    private func resetSessionState() {
        pendingStartRequestIdentifier = UUID()
        activeTranscriptionSession = nil
        draftCallbacks = nil
        activeStartSource = nil
        draftTextBeforeCurrentDictation = ""
        latestRecognizedText = ""
        shouldAutomaticallySubmitFinalDraft = false
        hasFinishedCurrentDictationSession = false
        isPreparingToRecord = false
        isRecordingFromMicrophoneButton = false
        isRecordingFromKeyboardShortcut = false
        isKeyboardShortcutSessionActiveOrFinalizing = false
        currentMicLifecycleIdentifier = nil
        activeStartRequestIdentifier = nil
        isFinalizingTranscript = false
        currentAudioPowerLevel = 0
        recordedAudioPowerHistory = Array(
            repeating: Self.recordedAudioPowerHistoryBaselineLevel,
            count: Self.recordedAudioPowerHistoryLength
        )
        microphoneButtonRecordingStartedAt = nil
        lastRecordedAudioPowerSampleDate = .distantPast
    }

    private func buildTranscriptionKeyterms() -> [String] {
        let baseKeyterms = [
            "Dexter",
            "dexter",
            "Visual Studio Code",
            "Claude",
            "Anthropic",
            "OpenAI",
            "SwiftUI",
            "Xcode",
            "Vercel",
            "Next.js",
            "localhost"
        ]

        let combinedKeyterms = baseKeyterms + contextualKeyterms
        var uniqueNormalizedKeyterms = Set<String>()
        var orderedKeyterms: [String] = []

        for keyterm in combinedKeyterms {
            let trimmedKeyterm = keyterm.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKeyterm.isEmpty else { continue }

            let normalizedKeyterm = trimmedKeyterm.lowercased()
            if uniqueNormalizedKeyterms.contains(normalizedKeyterm) {
                continue
            }

            uniqueNormalizedKeyterms.insert(normalizedKeyterm)
            orderedKeyterms.append(trimmedKeyterm)
        }

        return orderedKeyterms
    }

    private func logThrottledMicRawAudioBuffer(_ audioBuffer: AVAudioPCMBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastMicRawBufferDiagnosticLogDate) >= 0.5 else { return }
        lastMicRawBufferDiagnosticLogDate = now

        let frameCount = Int(audioBuffer.frameLength)
        let rootMeanSquare = rootMeanSquareLevel(from: audioBuffer)
        DexterMicRawLog.log("buffer received size=\(frameCount) rms=\(String(format: "%.5f", rootMeanSquare))")
    }

    private func logThrottledMicRuntimeAudioBuffer(_ audioBuffer: AVAudioPCMBuffer) {
        let now = Date()
        guard now.timeIntervalSince(lastMicRuntimeBufferDiagnosticLogDate) >= 1.0 else { return }
        lastMicRuntimeBufferDiagnosticLogDate = now

        let frameCount = Int(audioBuffer.frameLength)
        DexterMicRuntimeLog.log("AUDIO BUFFER RECEIVED size=\(frameCount)")
        let rootMeanSquare = rootMeanSquareLevel(from: audioBuffer)
        DexterMicRuntimeLog.log("RMS=\(String(format: "%.5f", rootMeanSquare))")
    }

    private func rootMeanSquareLevel(from audioBuffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = audioBuffer.floatChannelData else { return 0 }
        let frameCount = Int(audioBuffer.frameLength)
        guard frameCount > 0 else { return 0 }
        let channelSamples = channelData[0]
        var summedSquares: Float = 0
        for sampleIndex in 0..<frameCount {
            let sample = channelSamples[sampleIndex]
            summedSquares += sample * sample
        }
        return sqrt(summedSquares / Float(frameCount))
    }

    private func isBenignMicrophoneCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func updateAudioPowerLevel(from audioBuffer: AVAudioPCMBuffer) {
        guard let channelData = audioBuffer.floatChannelData else { return }

        let channelSamples = channelData[0]
        let frameCount = Int(audioBuffer.frameLength)
        guard frameCount > 0 else { return }

        var summedSquares: Float = 0
        for sampleIndex in 0..<frameCount {
            let sample = channelSamples[sampleIndex]
            summedSquares += sample * sample
        }

        let rootMeanSquare = sqrt(summedSquares / Float(frameCount))
        let boostedLevel = min(max(rootMeanSquare * 10.2, 0), 1)

        if rootMeanSquare > 0.0005 {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !self.hasLoggedNonZeroAudioSamples {
                    self.hasLoggedNonZeroAudioSamples = true
                    DexterMicDiagnosticLog.log("audio RMS=\(String(format: "%.5f", rootMeanSquare))")
                    DexterPermissionDiagnostics.logNonZeroAudioSamplesReceived(rmsLevel: rootMeanSquare)
                }
                self.microphoneHardwareInputDetected = true
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let smoothedAudioPowerLevel = max(
                CGFloat(boostedLevel),
                self.currentAudioPowerLevel * 0.72
            )
            self.currentAudioPowerLevel = smoothedAudioPowerLevel

            let now = Date()
            if now.timeIntervalSince(self.lastRecordedAudioPowerSampleDate)
                >= Self.recordedAudioPowerHistorySampleIntervalSeconds {
                self.lastRecordedAudioPowerSampleDate = now
                self.appendRecordedAudioPowerSample(
                    max(CGFloat(boostedLevel), Self.recordedAudioPowerHistoryBaselineLevel)
                )
            }
        }
    }

    private func appendRecordedAudioPowerSample(_ audioPowerSample: CGFloat) {
        var updatedRecordedAudioPowerHistory = recordedAudioPowerHistory
        updatedRecordedAudioPowerHistory.append(audioPowerSample)

        if updatedRecordedAudioPowerHistory.count > Self.recordedAudioPowerHistoryLength {
            updatedRecordedAudioPowerHistory.removeFirst(
                updatedRecordedAudioPowerHistory.count - Self.recordedAudioPowerHistoryLength
            )
        }

        recordedAudioPowerHistory = updatedRecordedAudioPowerHistory
    }

    private func requestMicrophoneAndSpeechPermissionsIfNeeded() async -> Bool {
        let hasMicrophonePermission = await requestMicrophonePermissionIfNeeded()
        guard hasMicrophonePermission else {
            lastMicrophoneErrorMessage = "Microphone access is required for push-to-talk."
            return false
        }

        guard transcriptionProvider.requiresSpeechRecognitionPermission else {
            return true
        }

        let hasSpeechRecognitionPermission = await requestSpeechRecognitionPermissionIfNeeded()
        guard hasSpeechRecognitionPermission else {
            speechToTextErrorMessage = "Allow Speech Recognition for Dexter in System Settings, then try again."
            return false
        }

        return true
    }

    /// macOS can show the microphone/speech sheet again if we accidentally fan out
    /// multiple permission requests before the first one finishes. We keep exactly
    /// one in-flight request task so rapid repeat presses all await the same result.
    ///
    /// After the task completes, we skip re-requesting for a short cooldown period
    /// so macOS has time to update its authorization cache. This prevents the
    /// permission dialog from popping up again on rapid follow-up presses.
    private func requestMicrophoneAndSpeechPermissionsWithoutDuplicatePrompts() async -> Bool {
        // If a permission request is already in-flight, reuse it.
        if let activePermissionRequestTask {
            return await activePermissionRequestTask.value
        }

        // If we just finished a permission request very recently, skip re-requesting.
        // macOS can briefly report .notDetermined even after the user tapped Allow,
        // so we trust the cached result for a short window.
        if let lastPermissionRequestCompletedAt,
           Date().timeIntervalSince(lastPermissionRequestCompletedAt) < 1.0 {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }

        let permissionRequestTask = Task { @MainActor in
            await self.requestMicrophoneAndSpeechPermissionsIfNeeded()
        }

        activePermissionRequestTask = permissionRequestTask

        let hasPermissions = await permissionRequestTask.value
        activePermissionRequestTask = nil
        lastPermissionRequestCompletedAt = Date()
        return hasPermissions
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DexterMicDiagnosticLog.log("permission status: \(describeMicrophoneAuthorization(authorizationStatus))")

        switch authorizationStatus {
        case .authorized:
            currentPermissionProblem = nil
            return true
        case .notDetermined:
            NSApplication.shared.activate(ignoringOtherApps: true)
            DexterMicDiagnosticLog.log("requesting permission")
            let isGranted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { isGranted in
                    continuation.resume(returning: isGranted)
                }
            }
            DexterMicDiagnosticLog.log("permission result: \(isGranted ? "granted" : "denied")")
            currentPermissionProblem = isGranted ? nil : .microphoneAccessDenied
            return isGranted
        case .denied, .restricted:
            currentPermissionProblem = .microphoneAccessDenied
            return false
        @unknown default:
            currentPermissionProblem = .microphoneAccessDenied
            return false
        }
    }

    private func describeMicrophoneAuthorization(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }

    private func requestSpeechRecognitionPermissionIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            currentPermissionProblem = nil
            return true
        case .notDetermined:
            let isGranted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authorizationStatus in
                    continuation.resume(returning: authorizationStatus == .authorized)
                }
            }
            currentPermissionProblem = isGranted ? nil : .speechRecognitionDenied
            return isGranted
        case .denied, .restricted:
            currentPermissionProblem = .speechRecognitionDenied
            return false
        @unknown default:
            currentPermissionProblem = .speechRecognitionDenied
            return false
        }
    }

    func openRelevantPrivacySettings() {
        let settingsURLString: String

        switch currentPermissionProblem {
        case .microphoneAccessDenied:
            settingsURLString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .speechRecognitionDenied:
            settingsURLString = "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        case nil:
            settingsURLString = "x-apple.systempreferences:com.apple.preference.security"
        }

        guard let settingsURL = URL(string: settingsURLString) else { return }
        NSWorkspace.shared.open(settingsURL)
    }

    private func userFacingErrorMessage(from error: Error, fallback: String) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !errorDescription.isEmpty {
            return errorDescription
        }

        let errorDescription = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !errorDescription.isEmpty,
           errorDescription != "The operation couldn’t be completed." {
            return errorDescription
        }

        return fallback
    }
}
