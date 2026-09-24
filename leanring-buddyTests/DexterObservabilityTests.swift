//
//  DexterObservabilityTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterObservabilityTests {
    @Test func redactionStripsApiKeyLikeTokens() {
        let input = "model_key=sk-live-abcdefghijklmnop"
        let redacted = DexterObservabilityRedaction.redact(input)
        #expect(!redacted.contains("sk-live-abcdefghijklmnop"))
        #expect(redacted.contains("sk-[REDACTED]"))
    }

    @Test func redactionStripsBearerTokens() {
        let input = "header Bearer abc.def.ghi"
        let redacted = DexterObservabilityRedaction.redact(input)
        #expect(redacted.contains("Bearer [REDACTED]"))
    }

    @Test func redactionReplacesSensitiveKeyNames() {
        let redacted = DexterObservabilityRedaction.redact("password=my-secret-value")
        #expect(redacted == "[REDACTED_SENSITIVE_FIELD]")
    }

    @Test func turnOutcomeMapsToOperationalCategory() {
        #expect(DexterTaskTraceRecorder.mapTurnOutcome(.success) == .success)
        #expect(DexterTaskTraceRecorder.mapTurnOutcome(.error) == .failure)
        #expect(DexterTaskTraceRecorder.mapTurnOutcome(.cancelled) == .cancelled)
        #expect(DexterTaskTraceRecorder.mapTurnOutcome(.timeout) == .timeout)
    }

    @Test func taskTraceRecordsLatencyBuckets() async throws {
        let recorder = DexterTaskTraceRecorder.shared
        #if DEBUG
        recorder.resetForTesting()
        #endif

        let taskIdentifier = recorder.beginTask()
        #expect(recorder.currentTaskIdentifier == taskIdentifier)

        _ = try await recorder.measure(bucket: .context) {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        recorder.recordLatency(bucket: .verification, milliseconds: 12)
        recorder.endTask(outcome: .success)

        #expect(recorder.currentTaskIdentifier == nil)
        #if DEBUG
        recorder.resetForTesting()
        #endif
    }

    @Test func tracePhasesFollowPipelineOrder() {
        let recorder = DexterTaskTraceRecorder.shared
        #if DEBUG
        recorder.resetForTesting()
        #endif

        _ = recorder.beginTask()
        recorder.markPhase(.context)
        recorder.markPhase(.intent)
        recorder.markPhase(.plan)
        recorder.markPhase(.permission)
        recorder.markPhase(.toolCalls)
        recorder.markPhase(.executionResults)
        recorder.markPhase(.observation)
        recorder.markPhase(.verification)

        let snapshot = recorder.snapshot()
        #expect(snapshot != nil)
        #expect(snapshot?.completedPhases.first == .invocation)
        #expect(snapshot?.completedPhases.contains(.verification) == true)

        recorder.endTask(outcome: .permissionDenied)
        #if DEBUG
        recorder.resetForTesting()
        #endif
    }
}
