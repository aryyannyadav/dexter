import Testing
@testable import leanring_buddy

@Suite("DexterHubEventMapper")
struct DexterHubEventMapperTests {
    @Test("verified completion maps to Hub success")
    func verifiedCompletionMapsToSuccess() {
        let snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: UUID(),
            actionIdentifier: UUID(),
            parentTaskIdentifier: nil,
            currentPhase: .completed,
            progressSummary: "Telegram is open.",
            receivedAt: Date(),
            updatedAt: Date(),
            completedAt: Date(),
            stepCount: 1,
            actionBudget: 1,
            toolBudget: 1,
            actionsConsumed: 1,
            toolsConsumed: 1,
            isCancellationRequested: false,
            timeoutSeconds: nil,
            errorInfo: nil,
            verificationStatus: .verified
        )

        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .done,
                statusDetail: "Telegram is open.",
                executionSnapshot: snapshot,
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .idle
            )
        )

        guard case .state(let hubState, let title, _, _, _, _, let verificationOutcome) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "success")
        #expect(title == "Done.")
        #expect(verificationOutcome == "verified")
    }

    @Test("partial verification never maps to Hub success")
    func partialVerificationNeverMapsToSuccess() {
        let snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: UUID(),
            actionIdentifier: UUID(),
            parentTaskIdentifier: nil,
            currentPhase: .completed,
            progressSummary: "The setting may have changed.",
            receivedAt: Date(),
            updatedAt: Date(),
            completedAt: Date(),
            stepCount: 1,
            actionBudget: 1,
            toolBudget: 1,
            actionsConsumed: 1,
            toolsConsumed: 1,
            isCancellationRequested: false,
            timeoutSeconds: nil,
            errorInfo: nil,
            verificationStatus: .partiallyVerified
        )

        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .done,
                statusDetail: "The setting may have changed.",
                executionSnapshot: snapshot,
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .idle
            )
        )

        guard case .state(let hubState, let title, _, _, _, let retrySupported, let verificationOutcome) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "thinking")
        #expect(title.contains("couldn't verify"))
        #expect(verificationOutcome == "partial")
        #expect(retrySupported == true)
    }

    @Test("failed verification maps to Hub error")
    func failedVerificationMapsToError() {
        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .failed,
                statusDetail: "Telegram didn't open.",
                executionSnapshot: DexterExecutionMachineSnapshot(
                    executionIdentifier: UUID(),
                    actionIdentifier: UUID(),
                    parentTaskIdentifier: nil,
                    currentPhase: .failed,
                    progressSummary: "Telegram didn't open.",
                    receivedAt: Date(),
                    updatedAt: Date(),
                    completedAt: nil,
                    stepCount: 1,
                    actionBudget: 1,
                    toolBudget: 1,
                    actionsConsumed: 1,
                    toolsConsumed: 1,
                    isCancellationRequested: false,
                    timeoutSeconds: nil,
                    errorInfo: DexterExecutionErrorInfo(code: "verification_failed", message: "Telegram didn't open."),
                    verificationStatus: .failed
                ),
                failurePresentation: DexterRuntimeUIFailurePresentation(
                    whatFailed: "Dexter couldn't finish the action",
                    why: "Telegram didn't open.",
                    whatYouCanDoNext: "Try again."
                ),
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .idle
            )
        )

        guard case .state(let hubState, let title, let subtitle, _, _, let retrySupported, _) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "error")
        #expect(title == "That didn't work.")
        #expect(subtitle == "Telegram didn't open.")
        #expect(retrySupported == true)
    }

    @Test("done without verified status never maps to Hub success")
    func doneWithoutVerifiedStatusNeverMapsToSuccess() {
        let snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: UUID(),
            actionIdentifier: UUID(),
            parentTaskIdentifier: nil,
            currentPhase: .completed,
            progressSummary: "Telegram is open.",
            receivedAt: Date(),
            updatedAt: Date(),
            completedAt: Date(),
            stepCount: 1,
            actionBudget: 1,
            toolBudget: 1,
            actionsConsumed: 1,
            toolsConsumed: 1,
            isCancellationRequested: false,
            timeoutSeconds: nil,
            errorInfo: nil,
            verificationStatus: .failed
        )

        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .done,
                statusDetail: "Telegram is open.",
                executionSnapshot: snapshot,
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .idle
            )
        )

        guard case .state(let hubState, _, _, _, _, _, _) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "idle")
    }

    @Test("done while speaking without execution snapshot maps to idle not success")
    func doneWhileSpeakingMapsToIdle() {
        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .done,
                statusDetail: "Speaking the response",
                executionSnapshot: nil,
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .idle
            )
        )

        guard case .state(let hubState, let title, _, _, _, _, _) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "idle")
        #expect(title == "hey, I'm here.")
    }

    @Test("permission denial does not advertise retry on Hub")
    func permissionDenialDoesNotAdvertiseRetry() {
        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .failed,
                statusDetail: "Permission denied",
                executionSnapshot: DexterExecutionMachineSnapshot(
                    executionIdentifier: UUID(),
                    actionIdentifier: UUID(),
                    parentTaskIdentifier: nil,
                    currentPhase: .failed,
                    progressSummary: "Permission denied",
                    receivedAt: Date(),
                    updatedAt: Date(),
                    completedAt: nil,
                    stepCount: 1,
                    actionBudget: 1,
                    toolBudget: 1,
                    actionsConsumed: 0,
                    toolsConsumed: 0,
                    isCancellationRequested: false,
                    timeoutSeconds: nil,
                    errorInfo: DexterExecutionErrorInfo(code: "permission_denied", message: "Permission denied"),
                    verificationStatus: nil
                ),
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .idle
            )
        )

        guard case .state(_, _, _, _, _, let retrySupported, _) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(retrySupported == false)
    }

    @Test("voice speaking maps to Hub speaking visual state")
    func voiceSpeakingMapsToSpeakingState() {
        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .done,
                statusDetail: "Speaking the response",
                executionSnapshot: nil,
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .speaking
            )
        )

        guard case .state(let hubState, let title, _, _, _, _, _) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "speaking")
        #expect(title == DexterHubVoicePresentation.speakingTitle)
    }

    @Test("voice STT error maps to did not catch copy")
    func voiceErrorMapsToDidNotCatch() {
        let mapped = DexterHubEventMapper.map(
            DexterHubEventMapper.Input(
                runtimeUIState: .idle,
                statusDetail: "",
                executionSnapshot: nil,
                failurePresentation: nil,
                pendingConfirmation: nil,
                isPointerMomentActive: false,
                voiceInteractionState: .error
            )
        )

        guard case .state(let hubState, let title, let subtitle, _, _, _, _) = mapped else {
            Issue.record("Expected state event")
            return
        }
        #expect(hubState == "aware")
        #expect(title == DexterHubVoicePresentation.didNotCatchTitle)
        #expect(subtitle == DexterHubVoicePresentation.didNotCatchSubtitle)
    }
}
