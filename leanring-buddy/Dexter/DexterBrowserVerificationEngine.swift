//
//  DexterBrowserVerificationEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterBrowserVerificationEngine {
    static func verify(
        action: DexterAction,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let browserAction = action.parameters["browserAction"] ?? inferredBrowserAction(for: action)
        let expectedHint = action.parameters["verificationHint"]
            ?? action.parameters["url"]
            ?? action.parameters["query"]
            ?? action.parameters["destination"]
            ?? ""

        let runtimeState = DexterBrowserRuntimeStateParser.parse(fromRawOutput: executionResult.rawOutput)
        let observedState = mergedBrowserState(
            environment: observationAfter.browserState,
            runtime: runtimeState
        )

        let expectedStateDescription = expectedStateDescription(
            browserAction: browserAction,
            expectedHint: expectedHint,
            action: action
        )
        let observedStateDescription = observedStateDescription(observedState)

        if !executionResult.reportedSuccess {
            return DexterActionVerificationReport(
                status: .failed,
                summary: "Browser action did not complete: \(executionResult.message)",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription,
                confidence: 0.9,
                evidence: ["runtime_reported_success=false"],
                reason: "OpenClaw browser dispatch failed."
            )
        }

        if browserAction == "read" {
            if let relevantText = observedState.relevantText, !relevantText.isEmpty {
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "Read browser content from the current page.",
                    expectedStateDescription: expectedStateDescription,
                    observedStateDescription: observedStateDescription,
                    confidence: 0.85,
                    evidence: ["browser_read_text_present=true"]
                )
            }
            return failedWithoutProof(
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if matchesExpectation(expectedHint: expectedHint, browserAction: browserAction, observedState: observedState) {
            return DexterActionVerificationReport(
                status: .verified,
                summary: verifiedSummary(browserAction: browserAction, expectedHint: expectedHint),
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription,
                confidence: 0.82,
                evidence: browserEvidence(observedState)
            )
        }

        if browserAction == "back" || browserAction == "forward" {
            if observedState.title != nil || observedState.url != nil {
                return DexterActionVerificationReport(
                    status: .partiallyVerified,
                    summary: "Browser history navigation was dispatched; page metadata changed or was returned by the runtime.",
                    expectedStateDescription: expectedStateDescription,
                    observedStateDescription: observedStateDescription,
                    confidence: 0.55,
                    evidence: browserEvidence(observedState)
                )
            }
        }

        return failedWithoutProof(
            expectedStateDescription: expectedStateDescription,
            observedStateDescription: observedStateDescription
        )
    }

    private static func failedWithoutProof(
        expectedStateDescription: String,
        observedStateDescription: String
    ) -> DexterActionVerificationReport {
        DexterActionVerificationReport(
            status: .failed,
            summary: "Dexter won't claim the browser action succeeded without URL/title evidence.",
            expectedStateDescription: expectedStateDescription,
            observedStateDescription: observedStateDescription,
            confidence: 0.88,
            evidence: ["browser_state_probe=insufficient"],
            reason: "Navigation or browser interaction was dispatched but independent browser state was not confirmed."
        )
    }

    private static func inferredBrowserAction(for action: DexterAction) -> String {
        switch action.type {
        case .openURL: return "open"
        case .navigate: return "navigate"
        default: return action.parameters["browserAction"] ?? "open"
        }
    }

    private static func mergedBrowserState(
        environment: DexterBrowserStateSnapshot,
        runtime: DexterBrowserStateSnapshot
    ) -> DexterBrowserStateSnapshot {
        DexterBrowserStateSnapshot(
            url: runtime.url ?? environment.url,
            title: runtime.title ?? environment.title,
            pageIdentity: runtime.pageIdentity ?? environment.pageIdentity,
            relevantText: runtime.relevantText ?? environment.relevantText,
            selectedElementDescription: runtime.selectedElementDescription ?? environment.selectedElementDescription,
            currentTaskDescription: environment.currentTaskDescription,
            availability: runtime.availability == .available || environment.availability == .available
                ? .available
                : .notApplicable
        )
    }

    private static func matchesExpectation(
        expectedHint: String,
        browserAction: String,
        observedState: DexterBrowserStateSnapshot
    ) -> Bool {
        let normalizedHint = expectedHint.lowercased()
        if normalizedHint.isEmpty {
            return observedState.url != nil || observedState.title != nil
        }

        if let url = observedState.url?.lowercased(), url.contains(normalizedHint) {
            return true
        }
        if let host = URL(string: observedState.url ?? "")?.host?.lowercased(), host.contains(normalizedHint) {
            return true
        }
        if let title = observedState.title?.lowercased(), title.contains(normalizedHint) {
            return true
        }
        if let pageIdentity = observedState.pageIdentity?.lowercased(), pageIdentity.contains(normalizedHint) {
            return true
        }

        if browserAction == "search", let title = observedState.title, !title.isEmpty {
            return true
        }

        return false
    }

    private static func expectedStateDescription(
        browserAction: String,
        expectedHint: String,
        action: DexterAction
    ) -> String {
        if !expectedHint.isEmpty {
            return "Browser should reflect \(browserAction) targeting \(expectedHint)."
        }
        return action.humanReadableDescription
    }

    private static func observedStateDescription(_ state: DexterBrowserStateSnapshot) -> String {
        var parts: [String] = []
        if let url = state.url { parts.append("url=\(url)") }
        if let title = state.title { parts.append("title=\(title)") }
        if let pageIdentity = state.pageIdentity { parts.append("pageIdentity=\(pageIdentity)") }
        if parts.isEmpty { return "No browser URL/title observation." }
        return parts.joined(separator: ", ")
    }

    private static func verifiedSummary(browserAction: String, expectedHint: String) -> String {
        if expectedHint.isEmpty {
            return "Browser \(browserAction) verified from page state."
        }
        return "Browser \(browserAction) verified for \(expectedHint)."
    }

    private static func browserEvidence(_ state: DexterBrowserStateSnapshot) -> [String] {
        var evidence: [String] = []
        if state.url != nil { evidence.append("observed_url=true") }
        if state.title != nil { evidence.append("observed_title=true") }
        if state.relevantText != nil { evidence.append("observed_text=true") }
        return evidence
    }
}
