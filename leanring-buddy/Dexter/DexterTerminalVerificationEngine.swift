//
//  DexterTerminalVerificationEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterTerminalVerificationEngine {
    static func verify(
        action: DexterAction,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let terminalAction = action.parameters["terminalAction"] ?? ""
        let expectedSubstring = action.parameters["expectedOutputContains"]
        let payload = DexterTerminalOperationResultPayload.decode(from: executionResult.rawOutput)

        if !executionResult.reportedSuccess {
            return DexterActionVerificationReport(
                status: .failed,
                summary: "Terminal action did not complete successfully.",
                expectedStateDescription: "Terminal \(terminalAction) should exit successfully.",
                observedStateDescription: executionResult.message,
                confidence: 0.9,
                evidence: ["exit_success=false"],
                reason: executionResult.message
            )
        }

        guard let payload else {
            return DexterActionVerificationReport(
                status: .failed,
                summary: "Dexter won't claim terminal success without captured output.",
                expectedStateDescription: "Terminal should return structured stdout/stderr.",
                observedStateDescription: "No terminal payload in runtime output.",
                confidence: 0.85,
                evidence: ["terminal_payload_missing=true"],
                reason: "missing_output"
            )
        }

        if payload.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DexterActionVerificationReport(
                status: .partiallyVerified,
                summary: "Command exited cleanly but produced no output.",
                expectedStateDescription: "Terminal capture should include output when expected.",
                observedStateDescription: "exitCode=\(payload.exitCode) outputLength=0",
                confidence: 0.55,
                evidence: ["output_empty=true"]
            )
        }

        if let expectedSubstring, !expectedSubstring.isEmpty {
            if payload.output.localizedCaseInsensitiveContains(expectedSubstring) {
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "Terminal output contains the expected result.",
                    expectedStateDescription: "Output should contain “\(expectedSubstring)”.",
                    observedStateDescription: "Captured \(payload.output.count) characters (sanitized).",
                    confidence: 0.88,
                    evidence: ["expected_output_match=true"]
                )
            }
            return DexterActionVerificationReport(
                status: .failed,
                summary: "Terminal output did not contain the expected result.",
                expectedStateDescription: "Output should contain “\(expectedSubstring)”.",
                observedStateDescription: "Captured output did not match.",
                confidence: 0.86,
                evidence: ["expected_output_match=false"],
                reason: "output_mismatch"
            )
        }

        if terminalAction == "captureOutput" || terminalAction == "inspect" {
            return DexterActionVerificationReport(
                status: .verified,
                summary: "Terminal output captured and sanitized.",
                expectedStateDescription: "Inspect/capture should return non-secret output.",
                observedStateDescription: "exitCode=\(payload.exitCode) outputLength=\(payload.output.count)",
                confidence: 0.8,
                evidence: ["terminal_output_captured=true"]
            )
        }

        return DexterActionVerificationReport(
            status: .partiallyVerified,
            summary: "Command ran; no expected output pattern was specified.",
            expectedStateDescription: action.humanReadableDescription,
            observedStateDescription: "exitCode=\(payload.exitCode)",
            confidence: 0.6,
            evidence: ["terminal_exit_ok=true"]
        )
    }
}
