//
//  DexterApplicationLifecycleVerificationTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

@MainActor
final class ConfigurableDexterApplicationLifecycleVerificationProbe: DexterApplicationLifecycleVerificationProbing {
    var signalsByApplicationName: [String: DexterOpenApplicationVerificationSignals] = [:]

    func verificationSignals(forApplicationName applicationName: String) -> DexterOpenApplicationVerificationSignals {
        signalsByApplicationName[applicationName] ?? DexterOpenApplicationVerificationSignals(
            isApplicationRunning: false,
            isApplicationFrontmost: false,
            hasVisibleWindow: false,
            observedRunningApplicationName: nil,
            observedRunningBundleIdentifier: nil
        )
    }
}

struct DexterApplicationLifecycleVerificationTests {
    private let genericApplicationName = "SampleTargetApplication"
    private let genericBundleIdentifier = "com.example.sampletarget"

    @Test @MainActor func launchVerificationRequiresRunningProcess() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = runningSignals(frontmost: true)
        let report = verifyLifecycle(
            action: DexterActionFactory.openApplication(named: genericApplicationName),
            probe: probe,
            executionResult: succeededRuntimeResult()
        )
        #expect(report.status == .verified)
        #expect(report.observedStateDescription.contains("running=true"))
        #expect(report.expectedStateDescription.contains("running"))
    }

    @Test @MainActor func launchVerificationFailsWhenApplicationIsNotRunning() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = notRunningSignals()
        let report = verifyLifecycle(
            action: DexterActionFactory.openApplication(named: genericApplicationName),
            probe: probe,
            executionResult: succeededRuntimeResult()
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("Verification failed"))
    }

    @Test @MainActor func quitVerificationRequiresProcessNotRunning() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = notRunningSignals()
        let report = verifyLifecycle(
            action: DexterActionFactory.quitApplication(named: genericApplicationName),
            probe: probe,
            executionResult: succeededRuntimeResult()
        )
        #expect(report.status == .verified)
        #expect(report.summary.contains("no longer running"))
        #expect(report.evidence.contains("process_running=false"))
    }

    @Test @MainActor func quitVerificationFailsWhenRuntimeSucceedsButProcessStillRunning() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = runningSignals(frontmost: true)
        let report = verifyLifecycle(
            action: DexterActionFactory.quitApplication(named: genericApplicationName),
            probe: probe,
            executionResult: succeededRuntimeResult()
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("Verification failed"))
        #expect(report.reason.contains("runtime success"))
    }

    @Test @MainActor func quitVerificationFailsWhenOnlyFrontmostIsFalseButProcessStillRunning() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = runningSignals(frontmost: false)
        let report = verifyLifecycle(
            action: DexterActionFactory.quitApplication(named: genericApplicationName),
            probe: probe,
            executionResult: succeededRuntimeResult()
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("still running"))
        #expect(report.evidence.contains("process_running=true"))
        #expect(report.evidence.contains("frontmost=false"))
    }

    @Test @MainActor func focusVerificationRequiresFrontmostApplication() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = runningSignals(frontmost: true)
        let report = verifyLifecycle(
            action: DexterActionFactory.focusApplication(named: genericApplicationName),
            probe: probe,
            executionResult: succeededRuntimeResult()
        )
        #expect(report.status == .verified)
    }

    @Test @MainActor func pipelineMarksVerificationFailureWhenQuitStillRunning() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = runningSignals(frontmost: false)
        let originalProbe = DexterActionVerificationEngine.applicationLifecycleProbe
        DexterActionVerificationEngine.applicationLifecycleProbe = probe
        defer { DexterActionVerificationEngine.applicationLifecycleProbe = originalProbe }

        let proposedAction = DexterActionFactory.quitApplication(named: genericApplicationName)
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: proposedAction,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "Quit SampleTargetApplication.")),
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: true
                )
            ),
            contextObserver: StubDexterActionContextObserver(),
            agentRuntime: TestRecordingAgentRuntime(result: succeededRuntimeResult()),
            actionVerifier: ObservingActionVerifier(),
            actionStore: InMemoryDexterActionStore(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionPermissionSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true),
            hasPersistedScreenContentGrant: true,
            confirmationGrant: DexterActionConfirmationGrant(
                actionId: proposedAction.id,
                riskLevelAtApprovalTime: .highRisk
            )
        )

        #expect(outcome.action.state == .verificationFailed)
        #expect(outcome.spokenSummary.contains("Verification failed"))
        #expect(outcome.verificationReport?.status == .failed)
    }

    @Test @MainActor func pipelineCancellationDoesNotReportSuccess() async throws {
        let cancellingRuntime = CancellationRecordingAgentRuntime()
        let proposedAction = DexterActionFactory.openApplication(named: genericApplicationName)

        let outcomeTask = Task {
            await DexterActionExecutionPipeline.execute(
                proposedAction: proposedAction,
                context: DexterContext(userMessage: DexterUserMessageContext(text: "Open SampleTargetApplication.")),
                permissionManager: StubPermissionManager(
                    snapshot: DexterPermissionSnapshot(
                        hasAccessibilityPermission: true,
                        hasScreenRecordingPermission: false,
                        hasMicrophonePermission: false,
                        hasScreenContentPermission: true
                    )
                ),
                contextObserver: StubDexterActionContextObserver(),
                agentRuntime: cancellingRuntime,
                actionVerifier: ObservingActionVerifier(),
                actionStore: InMemoryDexterActionStore(),
                actionHistoryStore: InMemoryDexterActionHistoryStore(),
                actionPermissionSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true),
                hasPersistedScreenContentGrant: true
            )
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        outcomeTask.cancel()
        let outcome = await outcomeTask.value

        #expect(outcome.action.state == .cancelled || outcome.action.state == .failed)
        #expect(!outcome.spokenSummary.lowercased().contains("verified"))
    }

    @Test @MainActor func lifecycleActionFactoryResolvesInstalledApplicationDisplayName() {
        let quitAction = DexterActionFactory.quitApplication(named: "calculator")
        #expect(quitAction.parameters["expectedOutcome"] == DexterExpectedOutcome.applicationNotRunning.rawValue)
        #expect(quitAction.parameters["verificationStrategy"] == DexterActionVerificationStrategyKind.applicationState.rawValue)
        if DexterInstalledApplicationLauncher.isApplicationInstalled(named: "Calculator") {
            #expect(quitAction.parameters["applicationName"] == "Calculator")
            #expect(quitAction.parameters["bundleIdentifier"] == "com.apple.calculator")
        }
    }

    @Test @MainActor func pipelineOpenClawDispatchFailureDoesNotMarkActionCompleted() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = notRunningSignals()
        let originalProbe = DexterActionVerificationEngine.applicationLifecycleProbe
        DexterActionVerificationEngine.applicationLifecycleProbe = probe
        defer { DexterActionVerificationEngine.applicationLifecycleProbe = originalProbe }

        let proposedAction = DexterActionFactory.openApplication(named: genericApplicationName)
        let failedDispatchMessage = "I couldn't open \(genericApplicationName) because the computer action failed. OpenClaw node invoke failed. Nothing was marked complete."
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: proposedAction,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "Open SampleTargetApplication.")),
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: true
                )
            ),
            contextObserver: StubDexterActionContextObserver(),
            agentRuntime: TestRecordingAgentRuntime(
                result: AgentActionResult(
                    reportedSuccess: false,
                    message: failedDispatchMessage,
                    executionStatus: .failed,
                    runtimeTaskIdentifier: nil,
                    rawOutput: "{\"code\":\"INVOKE_FAILED\"}"
                )
            ),
            actionVerifier: ObservingActionVerifier(),
            actionStore: InMemoryDexterActionStore(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionPermissionSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true),
            hasPersistedScreenContentGrant: true
        )

        #expect(outcome.action.state == .verificationFailed)
        #expect(outcome.verificationReport?.status == .failed)
        #expect(outcome.spokenSummary.contains("Nothing was marked complete"))
        #expect(outcome.executionSnapshot?.currentPhase == .failed)
        #expect(DexterTurnOutcomeResolver.resolveAfterApprovedActionExecution(outcome: outcome) == .error)
    }

    @Test @MainActor func pipelineRecordsRuntimeExecutionIdentifierOnTurnRecord() async throws {
        let probe = ConfigurableDexterApplicationLifecycleVerificationProbe()
        probe.signalsByApplicationName[genericApplicationName] = notRunningSignals()
        let originalProbe = DexterActionVerificationEngine.applicationLifecycleProbe
        DexterActionVerificationEngine.applicationLifecycleProbe = probe
        defer { DexterActionVerificationEngine.applicationLifecycleProbe = originalProbe }

        let proposedAction = DexterActionFactory.quitApplication(named: genericApplicationName)
        let outcome = await DexterActionExecutionPipeline.execute(
            proposedAction: proposedAction,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "Quit SampleTargetApplication.")),
            permissionManager: StubPermissionManager(
                snapshot: DexterPermissionSnapshot(
                    hasAccessibilityPermission: true,
                    hasScreenRecordingPermission: false,
                    hasMicrophonePermission: false,
                    hasScreenContentPermission: true
                )
            ),
            contextObserver: StubDexterActionContextObserver(),
            agentRuntime: TestRecordingAgentRuntime(
                result: AgentActionResult(
                    reportedSuccess: true,
                    message: "dispatch only",
                    executionStatus: .succeeded,
                    runtimeTaskIdentifier: "00000000-0000-4000-8000-000000000099",
                    rawOutput: "ok"
                )
            ),
            actionVerifier: ObservingActionVerifier(),
            actionStore: InMemoryDexterActionStore(),
            actionHistoryStore: InMemoryDexterActionHistoryStore(),
            actionPermissionSettings: DexterActionPermissionSettings(autoApproveLowRiskActions: true),
            hasPersistedScreenContentGrant: true,
            confirmationGrant: DexterActionConfirmationGrant(
                actionId: proposedAction.id,
                riskLevelAtApprovalTime: .highRisk
            )
        )

        #expect(outcome.turnRecord?.runtimeExecutionIdentifier == "00000000-0000-4000-8000-000000000099")
        #expect(outcome.action.state == .completed)
    }

    @Test @MainActor func runtimeExecutionGuardTimesOutLongRunningActions() async throws {
        let hangingRuntime = HangingAgentRuntime()
        let actionRequest = AgentActionRequest(
            actionIdentifier: DexterActionType.openApplication.rawValue,
            parameters: ["applicationName": genericApplicationName]
        )

        do {
            _ = try await DexterAgentRuntimeExecutionGuard.executeAction(
                agentRuntime: hangingRuntime,
                actionRequest: actionRequest,
                timeoutSeconds: 0.15
            )
            Issue.record("Expected timeout.")
        } catch let timeoutError as DexterAgentRuntimeExecutionGuard.TimeoutError {
            #expect(timeoutError.timeoutSeconds == 0.15)
        }
    }

    @MainActor
    private func verifyLifecycle(
        action: DexterAction,
        probe: ConfigurableDexterApplicationLifecycleVerificationProbe,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let originalProbe = DexterActionVerificationEngine.applicationLifecycleProbe
        DexterActionVerificationEngine.applicationLifecycleProbe = probe
        defer { DexterActionVerificationEngine.applicationLifecycleProbe = originalProbe }

        return DexterActionVerificationEngine.verify(
            action: action,
            observationBefore: .empty,
            observationAfter: .empty,
            executionResult: executionResult
        )
    }

    private func runningSignals(frontmost: Bool) -> DexterOpenApplicationVerificationSignals {
        DexterOpenApplicationVerificationSignals(
            isApplicationRunning: true,
            isApplicationFrontmost: frontmost,
            hasVisibleWindow: true,
            observedRunningApplicationName: genericApplicationName,
            observedRunningBundleIdentifier: genericBundleIdentifier
        )
    }

    private func notRunningSignals() -> DexterOpenApplicationVerificationSignals {
        DexterOpenApplicationVerificationSignals(
            isApplicationRunning: false,
            isApplicationFrontmost: false,
            hasVisibleWindow: false,
            observedRunningApplicationName: nil,
            observedRunningBundleIdentifier: nil
        )
    }

    private func succeededRuntimeResult() -> AgentActionResult {
        AgentActionResult(
            reportedSuccess: true,
            message: "Runtime dispatch reported success (must not imply task success).",
            executionStatus: .succeeded,
            runtimeTaskIdentifier: "runtime-task",
            rawOutput: "ok"
        )
    }
}

@MainActor
private final class TestRecordingAgentRuntime: AgentRuntime {
    let runtimeName = "TestRecordingRuntime"
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle
    private let result: AgentActionResult

    init(result: AgentActionResult) {
        self.result = result
    }

    func isAvailable() -> Bool { true }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        currentExecutionStatus = .running
        currentExecutionStatus = result.executionStatus
        return result
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        AgentActionCancellationResult(didCancel: false, message: "noop")
    }
}

@MainActor
private final class HangingAgentRuntime: AgentRuntime {
    let runtimeName = "HangingTestRuntime"
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    func isAvailable() -> Bool { true }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        currentExecutionStatus = .running
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return AgentActionResult(
            reportedSuccess: true,
            message: "should not return",
            executionStatus: .succeeded,
            runtimeTaskIdentifier: nil,
            rawOutput: nil
        )
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        AgentActionCancellationResult(didCancel: true, message: "cancelled")
    }
}

@MainActor
private final class CancellationRecordingAgentRuntime: AgentRuntime {
    let runtimeName = "CancellationTestRuntime"
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    func isAvailable() -> Bool { true }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        currentExecutionStatus = .running
        while !Task.isCancelled {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw CancellationError()
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        AgentActionCancellationResult(didCancel: true, message: "cancelled")
    }
}
