//
//  DexterDemonstrationMatrixTests.swift
//  leanring-buddyTests
//
//  Architecture contract tests for the eight product demonstrations (no mocked verification success).
//

import Foundation
import Testing
@testable import leanring_buddy

/// End-to-end live demos (OpenClaw gateway, TCC, PTT) are run manually in Xcode (Cmd+R).
/// These tests assert routing, planning, and verification policies for each demo path.
struct DexterDemonstrationMatrixTests {
    // MARK: - DEMO 1 — Computer understanding

    @Test func demo1_whatIsThisRoutesToExplainWithPointerTarget() {
        let intent = DexterIntentRouter.recognize(userMessage: "what is this?", context: nil)
        #expect(intent.kind == .explain)
        #expect(intent.target.reference == .currentPointerTarget)
        #expect(DexterIntentResponseModeMapper.responseMode(for: intent) == .explain)
        #expect(DexterContextRelevancePlanner.matchesWhatIsThisPublic("what is this"))
    }

    // MARK: - DEMO 2 — Teaching

    @Test func demo2_teachMeThisMapsToTeachingMode() {
        let intent = DexterIntentRouter.recognize(userMessage: "teach me this", context: nil)
        #expect(intent.kind == .teach)
        #expect(DexterIntentResponseModeMapper.responseMode(for: intent) == .teach)
    }

    // MARK: - DEMO 3 — Computer action (Calculator)

    @Test func demo3_openCalculatorPlansLifecycleAndOpenClawComputerAct() {
        let intent = DexterIntentRouter.recognize(userMessage: "open Calculator", context: nil)
        #expect(intent.kind == .open)
        #expect(DexterIntentResponseModeMapper.responseMode(for: intent) == .act)

        let plan = DexterActionPlanner.planAction(
            forUserMessage: "open Calculator",
            responseMode: .act,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "open Calculator")),
            demonstrationSessionStore: DexterDemonstrationSessionStore()
        )
        guard case .action(let action) = plan else {
            Issue.record("Expected open application action.")
            return
        }
        #expect(action.parameters["applicationName"] == "Calculator")

        let invocation = DexterRegisteredToolRouter.toolInvocation(
            for: DexterRegisteredToolProposal(
                toolName: DexterRegisteredToolName.applicationLaunch.rawValue,
                parameters: ["applicationName": "Calculator"]
            )
        )
        guard let toolInvocation = invocation else {
            Issue.record("Expected registered launch tool invocation.")
            return
        }
        let openClawPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: toolInvocation,
            executionIdentifier: "a1b2c3d4-e5f6-4789-abcd-ef0123456789",
            computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot(
                providerIdentifier: "peekaboo",
                providerLabel: "Peekaboo",
                contractVersion: 2,
                advertisedActions: OpenClawNodeComputerUseDescriptorSnapshot.dexterMappedComputerUseActions
            ),
            advertisedCommands: ["computer.act"]
        )
        #expect(openClawPlan?.parametersJSON.contains("launch_app") == true)
        #expect(openClawPlan?.parametersJSON.contains("Calculator") == true)
    }

    @Test @MainActor func demo3_quitCalculatorRequiresProcessNotRunningForVerifiedOutcome() {
        let probe = DexterDemonstrationMatrixLifecycleProbe()
        probe.signalsByApplicationName["Calculator"] = DexterOpenApplicationVerificationSignals(
            isApplicationRunning: true,
            isApplicationFrontmost: false,
            hasVisibleWindow: true,
            observedRunningApplicationName: "Calculator",
            observedRunningBundleIdentifier: "com.apple.calculator"
        )
        let originalProbe = DexterActionVerificationEngine.applicationLifecycleProbe
        DexterActionVerificationEngine.applicationLifecycleProbe = probe
        defer { DexterActionVerificationEngine.applicationLifecycleProbe = originalProbe }

        let report = DexterActionVerificationEngine.verify(
            action: DexterActionFactory.quitApplication(named: "Calculator"),
            observationBefore: .empty,
            observationAfter: .empty,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "task-quit",
                rawOutput: nil
            )
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("Verification failed"))
    }

    // MARK: - DEMO 4 — Browser

    @Test func demo4_searchForQueryUsesActModeAndStrictBrowserVerification() {
        let intent = DexterIntentRouter.recognize(userMessage: "search for Dexter macOS", context: nil)
        #expect(intent.kind == .search)
        #expect(DexterIntentResponseModeMapper.responseMode(for: intent) == .act)

        let browserReport = DexterBrowserVerificationEngine.verify(
            action: DexterActionFactory.browserSearch(query: "Dexter macOS"),
            observationAfter: DexterActionObservationSnapshot.empty,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "dispatched",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "browser-1",
                rawOutput: nil
            )
        )
        #expect(browserReport.status == .failed)
        #expect(browserReport.summary.contains("won't claim"))
    }

    // MARK: - DEMO 5 — Coding (explain → fix it)

    @Test func demo5_fixItRequiresPriorTaughtFixTag() {
        let emptyStore = DexterDemonstrationSessionStore()
        let withoutFix = DexterActionPlanner.planAction(
            forUserMessage: "fix it",
            responseMode: .act,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "fix it")),
            demonstrationSessionStore: emptyStore
        )
        guard case .unsupported = withoutFix else {
            Issue.record("fix it without taught fix must not plan a silent action.")
            return
        }

        let storeWithFix = DexterDemonstrationSessionStore()
        storeWithFix.recordProposedFix(
            fromAssistantResponse: "Use an empty array.\n[DEXTER_FIX:let items: [String] = []]"
        )
        let withFix = DexterActionPlanner.planAction(
            forUserMessage: "fix it",
            responseMode: .act,
            context: DexterContext(userMessage: DexterUserMessageContext(text: "fix it")),
            demonstrationSessionStore: storeWithFix
        )
        guard case .action(let action) = withFix else {
            Issue.record("Expected typeText action after taught fix.")
            return
        }
        #expect(action.type == .typeText)
    }

    // MARK: - DEMO 6 — Memory

    @Test func demo6_rememberAndRecallRoundTrip() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        let rememberOutcome = memoryStore.processMemoryIntents(
            fromUserMessage: "remember that my demo passphrase is horizon"
        )
        #expect(rememberOutcome == .appliedSilently)
        let recall = memoryStore.persistentMemoryContext(forQuery: "demo passphrase", limit: 4)
        #expect(recall.retrievedMemories.contains(where: { $0.content.contains("horizon") }))
    }

    // MARK: - DEMO 7 — Workflow

    @Test func demo7_workspaceSaveRestoreIntentsAndCatalogWorkflow() {
        #expect(DexterWorkspaceIntentRecognizer.recognizeSave(fromUserMessage: "save my workspace"))
        #expect(DexterWorkspaceIntentRecognizer.recognizeRestore(fromUserMessage: "restore my workspace"))
        let workflow = DexterWorkflowCatalog.workflowMatchingTrigger(userMessage: "prepare my coding environment")
        #expect(workflow != nil)
        #expect(workflow?.steps.isEmpty == false)
    }

    // MARK: - DEMO 8 — Voice

    @Test func demo8_voicePipelinePhasesAndSharedActRouting() {
        let phases = DexterCoreExecutionPipelinePhase.allCases.map(\.rawValue)
        #expect(phases.contains("PTT"))
        #expect(phases.contains("STT"))
        #expect(phases.contains("INTENT"))
        #expect(phases.contains("VERIFY"))
        #expect(phases.contains("TTS"))
        let voiceRoutedIntent = DexterIntentRouter.recognize(
            userMessage: "open Calculator",
            context: DexterContext(userMessage: DexterUserMessageContext(text: "open Calculator"))
        )
        #expect(DexterIntentResponseModeMapper.responseMode(for: voiceRoutedIntent) == .act)
    }
}

@MainActor
private final class DexterDemonstrationMatrixLifecycleProbe: DexterApplicationLifecycleVerificationProbing {
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
