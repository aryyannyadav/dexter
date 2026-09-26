//
//  DexterHubEventMapper.swift
//  leanring-buddy
//
//  Maps authoritative DexterRuntimeUIState → Hub wire events (no second state machine).
//

import Foundation

enum DexterHubEventMapper {
    struct Input: Equatable {
        let runtimeUIState: DexterRuntimeUIState
        let statusDetail: String
        let executionSnapshot: DexterExecutionMachineSnapshot?
        let failurePresentation: DexterRuntimeUIFailurePresentation?
        let pendingConfirmation: DexterActionConfirmationPresentation?
        let isPointerMomentActive: Bool
        let voiceInteractionState: DexterVoiceInteractionState
    }

    enum MappedEvent: Equatable {
        case state(
            hubState: String,
            title: String,
            subtitle: String?,
            application: String?,
            journeySteps: [DexterHubJourneyStep]?,
            retrySupported: Bool,
            verificationOutcome: String?
        )
        case context(application: String, windowTitle: String?, title: String)
        case permission(title: String, subtitle: String, actionIdentifier: String, actionDescription: String)
        case none
    }

    static func map(_ input: Input) -> MappedEvent {
        if input.voiceInteractionState == .error {
            return .state(
                hubState: "aware",
                title: DexterHubVoicePresentation.didNotCatchTitle,
                subtitle: DexterHubVoicePresentation.didNotCatchSubtitle,
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )
        }

        if input.voiceInteractionState == .speaking,
           !isActiveExecutionPhase(input.executionSnapshot?.currentPhase) {
            if input.isPointerMomentActive {
                return .none
            }
            let speakingSubtitle = DexterHubVoicePresentation.defaultSpeakingSubtitle
            return .state(
                hubState: "speaking",
                title: DexterHubVoicePresentation.speakingTitle,
                subtitle: speakingSubtitle,
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )
        }

        if input.voiceInteractionState == .listening {
            if input.isPointerMomentActive {
                return .none
            }
            return .state(
                hubState: "listening",
                title: "I'm listening...",
                subtitle: "Tell me what you need.",
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )
        }

        let journeySteps = DexterHubJourneySupport.journeySteps(
            for: input.executionSnapshot?.currentPhase
        )

        if let pendingConfirmation = input.pendingConfirmation,
           input.runtimeUIState == .waitingPermission
           || input.executionSnapshot?.currentPhase == .waitingPermission {
            let actionDescription = DexterHubJourneySupport.userSafeActionDetail(
                pendingConfirmation.content.whatWillHappen,
                fallback: "Run the planned action"
            )
            let permissionPrompt = input.isPointerMomentActive ? "Want me to fix it?" : "Want me to?"
            return .permission(
                title: permissionPrompt,
                subtitle: actionDescription,
                actionIdentifier: pendingConfirmation.actionId.uuidString,
                actionDescription: actionDescription
            )
        }

        switch input.runtimeUIState {
        case .idle:
            return .state(
                hubState: "idle",
                title: "hey, I'm here.",
                subtitle: "your digital companion",
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .listening:
            if input.isPointerMomentActive {
                return .none
            }
            return .state(
                hubState: "listening",
                title: "I'm listening...",
                subtitle: "Tell me what you need.",
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .understanding:
            return .state(
                hubState: "thinking",
                title: "thinking...",
                subtitle: DexterHubJourneySupport.userSafeActionDetail(
                    input.statusDetail,
                    fallback: "Understanding your request"
                ),
                application: nil,
                journeySteps: journeySteps,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .thinking, .planning:
            return .state(
                hubState: "thinking",
                title: "thinking...",
                subtitle: DexterHubJourneySupport.userSafeActionDetail(
                    input.statusDetail,
                    fallback: input.runtimeUIState == .planning ? "Planning next steps" : "Putting the pieces together"
                ),
                application: nil,
                journeySteps: journeySteps,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .waitingPermission:
            let detail = DexterHubJourneySupport.userSafeActionDetail(
                input.statusDetail,
                fallback: "Waiting for your approval"
            )
            let permissionPrompt = input.isPointerMomentActive ? "Want me to fix it?" : "Want me to?"
            return .state(
                hubState: "permission",
                title: permissionPrompt,
                subtitle: detail,
                application: nil,
                journeySteps: journeySteps,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .acting:
            let detail = DexterHubJourneySupport.userSafeActionDetail(
                input.statusDetail,
                fallback: "Running the approved action"
            )
            return .state(
                hubState: "acting",
                title: "ACTING",
                subtitle: detail,
                application: extractApplicationName(from: detail),
                journeySteps: journeySteps,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .verifying:
            return .state(
                hubState: "verifying",
                title: "CHECKING",
                subtitle: "Making sure it worked.",
                application: nil,
                journeySteps: journeySteps,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .done:
            if let snapshot = input.executionSnapshot,
               snapshot.currentPhase == .completed {
                let detail = DexterHubJourneySupport.userSafeActionDetail(
                    input.statusDetail,
                    fallback: "Ready"
                )
                switch snapshot.verificationStatus {
                case .verified:
                    return .state(
                        hubState: "success",
                        title: "Done.",
                        subtitle: detail,
                        application: extractApplicationName(from: detail),
                        journeySteps: journeySteps,
                        retrySupported: false,
                        verificationOutcome: "verified"
                    )
                case .partiallyVerified:
                    return .state(
                        hubState: "thinking",
                        title: "I completed the action, but I couldn't verify the result.",
                        subtitle: detail,
                        application: extractApplicationName(from: detail),
                        journeySteps: journeySteps,
                        retrySupported: true,
                        verificationOutcome: "partial"
                    )
                case .failed, .unavailable, .none:
                    break
                }
            }
            return .state(
                hubState: "idle",
                title: "hey, I'm here.",
                subtitle: "your digital companion",
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )

        case .failed:
            let errorCode = input.executionSnapshot?.errorInfo?.code
            let whyMessage = input.failurePresentation?.why
                ?? DexterHubJourneySupport.userSafeActionDetail(
                    input.statusDetail,
                    fallback: "Something went wrong."
                )
            let retrySupported = DexterHubJourneySupport.retryIsSupported(forErrorCode: errorCode)
            let failureJourneySteps = DexterHubJourneySupport.journeyStepsForFailure(
                executionSnapshot: input.executionSnapshot
            )
            return .state(
                hubState: "error",
                title: "That didn't work.",
                subtitle: whyMessage,
                application: nil,
                journeySteps: failureJourneySteps,
                retrySupported: retrySupported,
                verificationOutcome: "failed"
            )

        case .cancelled:
            return .state(
                hubState: "idle",
                title: "hey, I'm here.",
                subtitle: "your digital companion",
                application: nil,
                journeySteps: nil,
                retrySupported: false,
                verificationOutcome: nil
            )
        }
    }

    static func contextEvent(applicationName: String, windowTitle: String?) -> MappedEvent {
        .context(
            application: applicationName,
            windowTitle: windowTitle,
            title: "I see what you're working on."
        )
    }

    private static func extractApplicationName(from detail: String) -> String? {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("opening ") {
            return String(trimmed.dropFirst("opening ".count))
        }
        return nil
    }

    private static func isActiveExecutionPhase(_ phase: DexterExecutionPhase?) -> Bool {
        guard let phase else { return false }
        switch phase {
        case .executing, .verifying, .waitingPermission, .planning:
            return true
        case .received, .understanding, .completed, .failed, .cancelled:
            return false
        }
    }
}
