//
//  DexterWorkflowLearningEngineTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterWorkflowLearningEngineTests {
    @Test func catalogMatchesPrepareCodingEnvironmentTrigger() {
        let workflow = DexterWorkflowCatalog.workflowMatchingTrigger(
            userMessage: "Please prepare my coding environment."
        )
        #expect(workflow?.workflowIdentifier == DexterWorkflowCatalog.prepareCodingEnvironmentIdentifier)
        #expect(workflow?.steps.count == 6)
    }

    @Test func stepPlannerRejectsCoordinateParameters() {
        let workflow = DexterWorkflowCatalog.workflow(forIdentifier: DexterWorkflowCatalog.prepareCodingEnvironmentIdentifier)!
        let step = DexterWorkflowStepDefinition(
            id: UUID(),
            title: "Bad click",
            instruction: "Should not run.",
            actionKind: .openApplication,
            parameters: ["applicationName": "Safari", "x": "10", "y": "20"],
            verification: nil,
            contextRequirements: workflow.contextRequirements,
            requiredPermissions: []
        )
        let outcome = DexterWorkflowStepPlanner.plan(
            step: step,
            workflow: workflow,
            context: workflowContext()
        )
        #expect(outcome == .failed("Workflow steps cannot include screen coordinates."))
    }

    @Test func runtimeCancelsActiveSession() async {
        let workflow = DexterWorkflowCatalog.workflow(forIdentifier: DexterWorkflowCatalog.prepareCodingEnvironmentIdentifier)!
        let session = DexterWorkflowRunSession(
            workflowIdentifier: workflow.workflowIdentifier,
            workflowName: workflow.name
        )

        let outcome = await DexterWorkflowRuntimeEngine.processTurn(
            userMessage: "cancel workflow",
            workflow: workflow,
            session: session,
            context: workflowContext(),
            executeVerifiedAction: { _ in fatalError("Should not execute on cancel") }
        )

        #expect(outcome.session.runtimePhase == .cancelled)
        #expect(outcome.spokenSummary.contains("Cancelled"))
    }

    @Test func runtimeRunsFirstStepOnTriggerPhrase() async {
        let workflow = DexterWorkflowCatalog.workflow(forIdentifier: DexterWorkflowCatalog.prepareCodingEnvironmentIdentifier)!
        let session = DexterWorkflowRunSession(
            workflowIdentifier: workflow.workflowIdentifier,
            workflowName: workflow.name
        )

        let outcome = await DexterWorkflowRuntimeEngine.processTurn(
            userMessage: "prepare my coding environment",
            workflow: workflow,
            session: session,
            context: workflowContext(),
            executeVerifiedAction: { proposedAction in
                let completedAction = proposedAction.withState(.completed)
                return DexterActionExecutionOutcome(
                    action: completedAction,
                    spokenSummary: "Opened VS Code.",
                    pendingConfirmation: nil,
                    verificationReport: nil,
                    turnRecord: nil,
                    executionSnapshot: nil,
                    recoveryMetadata: nil
                )
            }
        )

        #expect(outcome.session.currentStepIndex == 1)
        #expect(outcome.spokenSummary.contains("Open project"))
    }

    @Test func recordingFromObservedActionsIsDisabled() {
        #expect(DexterWorkflowRecordingEngine.isRecordingFromObservedActionsEnabled == false)
    }

    private static func workflowContext() -> DexterContext {
        DexterContext(
            userMessage: DexterUserMessageContext(text: "prepare my coding environment"),
            activeApplication: DexterActiveApplicationContext(
                bundleIdentifier: "com.microsoft.VSCode",
                localizedName: "Visual Studio Code",
                availability: .available
            ),
            activeWindow: DexterActiveWindowContext(title: "Dexter", availability: .available)
        )
    }
}
