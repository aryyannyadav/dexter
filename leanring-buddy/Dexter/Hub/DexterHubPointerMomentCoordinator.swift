//
//  DexterHubPointerMomentCoordinator.swift
//  leanring-buddy
//
//  Sequences Hub events for Point → Understand → Act (presentation only).
//

import Combine
import Foundation

@MainActor
final class DexterHubPointerMomentCoordinator {
    private weak var eventBridge: DexterHubEventBridge?
    private var cancellables = Set<AnyCancellable>()
    private var understandingBeatTask: Task<Void, Never>?
    private var pointerWakeTask: Task<Void, Never>?
    private var pointerUncertaintyTask: Task<Void, Never>?
    private var lastAnswerFingerprint: String?
    private var didSendUnderstandingGotIt = false
    private var pointerApplicationName: String?
    private var pointerTargetSubtitle: String?

    func install(
        eventBridge: DexterHubEventBridge,
        pointInvokeSessionPublisher: AnyPublisher<DexterPointInvokeSession?, Never>,
        voiceInteractionStatePublisher: AnyPublisher<DexterVoiceInteractionState, Never>,
        streamingResponseTextPublisher: AnyPublisher<String, Never>
    ) {
        self.eventBridge = eventBridge

        pointInvokeSessionPublisher
            .removeDuplicates()
            .sink { [weak self] session in
                self?.handlePointInvokeSessionChanged(session)
            }
            .store(in: &cancellables)

        voiceInteractionStatePublisher
            .removeDuplicates()
            .sink { [weak self] voiceState in
                self?.handleVoiceInteractionStateChanged(voiceState)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(voiceInteractionStatePublisher, streamingResponseTextPublisher)
            .sink { [weak self] voiceState, responseText in
                self?.handleResponseProgress(voiceState: voiceState, responseText: responseText)
            }
            .store(in: &cancellables)
    }

    private func handlePointInvokeSessionChanged(_ session: DexterPointInvokeSession?) {
        understandingBeatTask?.cancel()
        pointerWakeTask?.cancel()
        pointerUncertaintyTask?.cancel()
        didSendUnderstandingGotIt = false
        lastAnswerFingerprint = nil

        guard let session else {
            eventBridge?.setPointerMomentActive(false, applicationName: nil)
            pointerApplicationName = nil
            pointerTargetSubtitle = nil
            return
        }

        let applicationName = session.activeApplicationDisplayName?.nonEmptyTrimmedValue ?? "your screen"
        let windowTitle = session.activeWindowTitle?.nonEmptyTrimmedValue
        let targetSubtitle = session.hubTargetPresentationSubtitle

        pointerApplicationName = applicationName
        pointerTargetSubtitle = targetSubtitle

        let confidenceLabel = session.pointerSemanticTarget.map { String(format: "%.2f", $0.confidence) } ?? "none"
        DexterObservabilityLog.voice(
            "point_invoke hub target=\(session.userFacingSemanticTargetLabel ?? "none") "
                + "source=\(session.primaryResolutionSourceForDiagnostics) confidence=\(confidenceLabel)"
        )

        eventBridge?.setPointerMomentActive(true, applicationName: applicationName)

        pointerWakeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            self?.eventBridge?.broadcastPointerAware(
                applicationName: applicationName,
                windowTitle: windowTitle,
                targetSubtitle: targetSubtitle
            )

            guard session.requiresHubTargetConfirmationBeat,
                  let uncertainLabel = session.hubUncertainTargetPromptLabel
            else {
                return
            }

            self?.pointerUncertaintyTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 520_000_000)
                guard !Task.isCancelled else { return }
                guard self?.eventBridge?.isPointerMomentActive == true else { return }
                self?.eventBridge?.broadcastPointerTargetUncertainty(
                    targetLabel: uncertainLabel,
                    applicationName: applicationName
                )
            }
        }
    }

    private func handleVoiceInteractionStateChanged(_ voiceState: DexterVoiceInteractionState) {
        guard eventBridge?.isPointerMomentActive == true else { return }

        switch voiceState {
        case .speaking:
            eventBridge?.broadcastPointerSpeaking(
                applicationName: pointerApplicationName,
                targetSubtitle: pointerTargetSubtitle
            )
        case .listening:
            eventBridge?.broadcastPointerListening(
                applicationName: pointerApplicationName,
                targetSubtitle: pointerTargetSubtitle
            )
        case .transcribing:
            didSendUnderstandingGotIt = false
            eventBridge?.broadcastUnderstandingLook(
                applicationName: pointerApplicationName,
                targetSubtitle: pointerTargetSubtitle
            )
            scheduleUnderstandingGotItBeat()
        case .idle, .error:
            break
        case .thinking:
            if !didSendUnderstandingGotIt {
                scheduleUnderstandingGotItBeat(delayNanoseconds: 120_000_000)
            }
        }
    }

    private func handleResponseProgress(voiceState: DexterVoiceInteractionState, responseText: String) {
        guard eventBridge?.isPointerMomentActive == true else { return }
        guard voiceState == .speaking || voiceState == .thinking else { return }

        let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedResponse.count >= 24 else { return }

        let fingerprint = String(trimmedResponse.prefix(96))
        guard fingerprint != lastAnswerFingerprint else { return }
        lastAnswerFingerprint = fingerprint

        let summary = DexterHubAmbientSummaryBuilder.build(from: trimmedResponse)
        eventBridge?.broadcastAnswerSummary(
            title: summary.title,
            subtitle: summary.subtitle,
            applicationName: pointerApplicationName
        )
    }

    private func scheduleUnderstandingGotItBeat(delayNanoseconds: UInt64 = 480_000_000) {
        understandingBeatTask?.cancel()
        understandingBeatTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            guard self?.eventBridge?.isPointerMomentActive == true else { return }
            self?.didSendUnderstandingGotIt = true
            self?.eventBridge?.broadcastUnderstandingGotIt(
                applicationName: self?.pointerApplicationName,
                targetSubtitle: self?.pointerTargetSubtitle
            )
        }
    }
}
