//
//  DexterHubJourneySupport.swift
//  leanring-buddy
//
//  Action journey presentation for Dexter Hub (maps existing execution phases only).
//

import Foundation

struct DexterHubJourneyStep: Equatable {
    let label: String
    let status: String
}

enum DexterHubJourneySupport {
    static func journeySteps(for executionPhase: DexterExecutionPhase?) -> [DexterHubJourneyStep]? {
        guard let executionPhase else { return nil }

        switch executionPhase {
        case .received, .understanding:
            return [
                step("UNDERSTAND", "active"),
                step("PLAN", "pending"),
                step("ASK", "pending"),
                step("ACT", "pending"),
                step("VERIFY", "pending"),
            ]
        case .planning:
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "active"),
                step("ASK", "pending"),
                step("ACT", "pending"),
                step("VERIFY", "pending"),
            ]
        case .waitingPermission:
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "active"),
                step("ACT", "pending"),
                step("VERIFY", "pending"),
            ]
        case .executing:
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "done"),
                step("ACT", "active"),
                step("VERIFY", "pending"),
            ]
        case .verifying:
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "done"),
                step("ACT", "done"),
                step("VERIFY", "active"),
            ]
        case .completed:
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "done"),
                step("ACT", "done"),
                step("VERIFY", "done"),
            ]
        case .failed, .cancelled:
            return nil
        }
    }

    static func journeyStepsForFailure(
        executionSnapshot: DexterExecutionMachineSnapshot?
    ) -> [DexterHubJourneyStep]? {
        guard let executionSnapshot else { return nil }
        let errorCode = executionSnapshot.errorInfo?.code ?? ""

        if errorCode == "verification_failed"
            || executionSnapshot.verificationStatus == .failed
            || executionSnapshot.currentPhase == .verifying {
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "done"),
                step("ACT", "done"),
                step("VERIFY", "failed"),
            ]
        }

        if executionSnapshot.currentPhase == .executing {
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "done"),
                step("ACT", "failed"),
                step("VERIFY", "pending"),
            ]
        }

        if executionSnapshot.currentPhase == .waitingPermission {
            return [
                step("UNDERSTAND", "done"),
                step("PLAN", "done"),
                step("ASK", "failed"),
                step("ACT", "pending"),
                step("VERIFY", "pending"),
            ]
        }

        return [
            step("UNDERSTAND", "done"),
            step("PLAN", "done"),
            step("ASK", "done"),
            step("ACT", "done"),
            step("VERIFY", "failed"),
        ]
    }

    private static func step(_ label: String, _ status: String) -> DexterHubJourneyStep {
        DexterHubJourneyStep(label: label, status: status)
    }

    static func userSafeActionDetail(_ detail: String, fallback: String) -> String {
        let sanitized = sanitizeTechnicalHubDetail(detail)
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        if trimmed.lowercased() == "waiting for your approval in the dexter panel." {
            return fallback
        }
        return trimmed
    }

    static func sanitizeTechnicalHubDetail(_ detail: String) -> String {
        let lowered = detail.lowercased()
        let bannedSubstrings = [
            "openclaw",
            "tool gateway",
            "agent runtime",
            "computer.act",
            "browser.proxy",
            "ollama",
            "anthropic",
            "claude",
            "gpt-",
            "json",
            "invoke plan",
        ]
        if bannedSubstrings.contains(where: { lowered.contains($0) }) {
            return ""
        }
        return detail
    }

    static func retryIsSupported(forErrorCode errorCode: String?) -> Bool {
        guard let errorCode else { return true }
        switch errorCode {
        case "permission_denied", "cancelled":
            return false
        default:
            return true
        }
    }
}
