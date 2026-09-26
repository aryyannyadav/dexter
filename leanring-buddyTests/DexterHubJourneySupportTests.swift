import Testing
@testable import leanring_buddy

@Suite("DexterHubJourneySupport")
struct DexterHubJourneySupportTests {
    @Test("permission phase maps ASK as active")
    func permissionPhaseMapsAskActive() {
        let steps = DexterHubJourneySupport.journeySteps(for: .waitingPermission)
        #expect(steps?.map(\.label) == ["UNDERSTAND", "PLAN", "ASK", "ACT", "VERIFY"])
        #expect(steps?.first(where: { $0.label == "ASK" })?.status == "active")
    }

    @Test("verification failure marks VERIFY failed")
    func verificationFailureMarksVerifyFailed() {
        let snapshot = DexterExecutionMachineSnapshot(
            executionIdentifier: UUID(),
            actionIdentifier: UUID(),
            parentTaskIdentifier: nil,
            currentPhase: .failed,
            progressSummary: "Could not verify",
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
            errorInfo: DexterExecutionErrorInfo(code: "verification_failed", message: "failed"),
            verificationStatus: .failed
        )
        let steps = DexterHubJourneySupport.journeyStepsForFailure(executionSnapshot: snapshot)
        #expect(steps?.last?.label == "VERIFY")
        #expect(steps?.last?.status == "failed")
    }
}
