//
//  DexterActionVerificationEngine.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterActionVerificationStatus: String, Equatable {
    case verified = "VERIFIED"
    case partiallyVerified = "PARTIALLY_VERIFIED"
    case unavailable = "UNAVAILABLE"
    case failed = "FAILED"
}

struct DexterActionVerificationReport: Equatable {
    let status: DexterActionVerificationStatus
    /// User-facing outcome (never raw runtime / HTTP success alone).
    let summary: String
    let expectedStateDescription: String
    let observedStateDescription: String
    /// 0...1 confidence in the verification conclusion.
    let confidence: Double
    let evidence: [String]
    let reason: String

    var intendedStateDescription: String { expectedStateDescription }

    init(
        status: DexterActionVerificationStatus,
        summary: String,
        expectedStateDescription: String,
        observedStateDescription: String,
        confidence: Double = 1.0,
        evidence: [String] = [],
        reason: String? = nil
    ) {
        self.status = status
        self.summary = summary
        self.expectedStateDescription = expectedStateDescription
        self.observedStateDescription = observedStateDescription
        self.confidence = confidence
        self.evidence = evidence
        self.reason = reason ?? summary
    }
}

/// Observes whether a named application is running (used by verification; swappable in tests).
@MainActor
protocol DexterApplicationLifecycleVerificationProbing: AnyObject {
    func verificationSignals(forApplicationName applicationName: String) -> DexterOpenApplicationVerificationSignals
}

@MainActor
final class SystemDexterApplicationLifecycleVerificationProbe: DexterApplicationLifecycleVerificationProbing {
    func verificationSignals(forApplicationName applicationName: String) -> DexterOpenApplicationVerificationSignals {
        DexterOpenApplicationVerification.signals(forApplicationName: applicationName)
    }
}

enum DexterActionVerificationEngine {
    @MainActor
    static var applicationLifecycleProbe: DexterApplicationLifecycleVerificationProbing =
        SystemDexterApplicationLifecycleVerificationProbe()

    static func requiresPostExecutionObservationSettle(for action: DexterAction) -> Bool {
        switch action.type {
        case .openApplication, .focusApplication, .quitApplication:
            return true
        default:
            return false
        }
    }

    @MainActor
    static func verify(
        action: DexterAction,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        switch action.type {
        case .openApplication:
            return verifyOpenApplication(
                action: action,
                observationAfter: observationAfter,
                executionResult: executionResult,
                expectedRunning: true
            )

        case .focusApplication:
            return verifyOpenApplication(
                action: action,
                observationAfter: observationAfter,
                executionResult: executionResult,
                expectedRunning: true,
                requireFrontmost: true
            )

        case .quitApplication:
            return verifyQuitApplication(
                action: action,
                executionResult: executionResult
            )

        case .click:
            if action.parameters["browserAction"] != nil {
                return DexterBrowserVerificationEngine.verify(
                    action: action,
                    observationAfter: observationAfter,
                    executionResult: executionResult
                )
            }
            return verifyClick(
                action: action,
                observationBefore: observationBefore,
                observationAfter: observationAfter,
                executionResult: executionResult
            )

        case .typeText:
            if action.parameters["browserAction"] != nil {
                return DexterBrowserVerificationEngine.verify(
                    action: action,
                    observationAfter: observationAfter,
                    executionResult: executionResult
                )
            }
            return verifyTypeText(
                action: action,
                observationAfter: observationAfter,
                executionResult: executionResult
            )

        case .openURL, .navigate:
            return DexterBrowserVerificationEngine.verify(
                action: action,
                observationAfter: observationAfter,
                executionResult: executionResult
            )

        case .fileOperation:
            return DexterFileVerificationEngine.verify(
                action: action,
                executionResult: executionResult
            )

        case .terminalOperation:
            return DexterTerminalVerificationEngine.verify(
                action: action,
                executionResult: executionResult
            )

        default:
            return verifyWithRuntimeHintOnly(action: action, executionResult: executionResult, observationAfter: observationAfter)
        }
    }

    @MainActor
    private static func verifyOpenApplication(
        action: DexterAction,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult,
        expectedRunning: Bool,
        requireFrontmost: Bool = false
    ) -> DexterActionVerificationReport {
        let intendedApplicationName = action.parameters["applicationName"] ?? "the application"
        let verb = requireFrontmost ? "focused" : "open"
        let expectedStateDescription = requireFrontmost
            ? "\(intendedApplicationName) should be running and frontmost."
            : "\(intendedApplicationName) should be running with a visible window when applicable."

        let launchSignals = applicationLifecycleProbe.verificationSignals(forApplicationName: intendedApplicationName)
        DexterActionDiagnosticLog.verify("running=\(launchSignals.isApplicationRunning)")
        DexterActionDiagnosticLog.verify("visible=\(launchSignals.hasVisibleWindow)")
        DexterActionDiagnosticLog.verify("frontmost=\(launchSignals.isApplicationFrontmost)")

        let observedApplicationName = launchSignals.observedRunningApplicationName
            ?? observationAfter.activeApplicationLocalizedName
            ?? "unknown application"
        let observedBundleIdentifier = launchSignals.observedRunningBundleIdentifier
            ?? observationAfter.activeApplicationBundleIdentifier
            ?? "unknown bundle"
        let observedStateDescription =
            "running=\(launchSignals.isApplicationRunning), visible=\(launchSignals.hasVisibleWindow), frontmost=\(launchSignals.isApplicationFrontmost), app=\(observedApplicationName) (\(observedBundleIdentifier))."

        if expectedRunning && launchSignals.isApplicationRunning {
            if requireFrontmost {
                if launchSignals.isApplicationFrontmost {
                    DexterActionDiagnosticLog.verify("result=verified")
                    return DexterActionVerificationReport(
                        status: .verified,
                        summary: "Done — \(intendedApplicationName) is in front.",
                        expectedStateDescription: expectedStateDescription,
                        observedStateDescription: observedStateDescription
                    )
                }

                DexterActionDiagnosticLog.verify("result=partiallyVerified")
                return DexterActionVerificationReport(
                    status: .partiallyVerified,
                    summary: "\(intendedApplicationName) is running, but it isn't the frontmost window.",
                    expectedStateDescription: expectedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }

            if launchSignals.isApplicationFrontmost {
                DexterActionDiagnosticLog.verify("result=verified")
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "\(intendedApplicationName) is open.",
                    expectedStateDescription: expectedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }

            if launchSignals.hasVisibleWindow {
                DexterActionDiagnosticLog.verify("result=partiallyVerified")
                return DexterActionVerificationReport(
                    status: .partiallyVerified,
                    summary: "\(intendedApplicationName) is open, although it isn't the frontmost window.",
                    expectedStateDescription: expectedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }

            DexterActionDiagnosticLog.verify("result=partiallyVerified")
            return DexterActionVerificationReport(
                status: .partiallyVerified,
                summary: "\(intendedApplicationName) is running, but Dexter could not confirm a visible window.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if !executionResult.reportedSuccess {
            DexterActionDiagnosticLog.verify("result=failed")
            let failureSummary = executionResult.message.nonEmptyTrimmedValue
                ?? "I couldn't \(verb) \(intendedApplicationName)."
            return DexterActionVerificationReport(
                status: .failed,
                summary: failureSummary,
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        DexterActionDiagnosticLog.verify("result=failed")
        let failureSummary =
            "Verification failed: \(intendedApplicationName) is not running after the \(verb) action. Dexter does not treat runtime dispatch success as task success."
        return DexterActionVerificationReport(
            status: .failed,
            summary: failureSummary,
            expectedStateDescription: expectedStateDescription,
            observedStateDescription: observedStateDescription,
            confidence: 0.9,
            evidence: [
                "process_running=false",
                "runtime_reported_success=\(executionResult.reportedSuccess)",
            ],
            reason: failureSummary
        )
    }

    @MainActor
    private static func verifyQuitApplication(
        action: DexterAction,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let intendedApplicationName = action.parameters["applicationName"] ?? "the application"
        let expectedStateDescription = "\(intendedApplicationName) must not have a running process."

        let launchSignals = applicationLifecycleProbe.verificationSignals(forApplicationName: intendedApplicationName)
        DexterActionDiagnosticLog.verify("running=\(launchSignals.isApplicationRunning)")
        DexterActionDiagnosticLog.verify("visible=\(launchSignals.hasVisibleWindow)")
        DexterActionDiagnosticLog.verify("frontmost=\(launchSignals.isApplicationFrontmost)")

        let observedStateDescription = quitObservedStateDescription(from: launchSignals)
        let evidence = quitEvidenceLines(from: launchSignals)

        if !launchSignals.isApplicationRunning {
            DexterActionDiagnosticLog.verify("result=verified")
            return DexterActionVerificationReport(
                status: .verified,
                summary: "Verified — \(intendedApplicationName) is no longer running.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription,
                confidence: 0.95,
                evidence: evidence,
                reason: "No matching running process was observed after the quit action."
            )
        }

        if !executionResult.reportedSuccess {
            DexterActionDiagnosticLog.verify("result=failed")
            let runtimeMessage = executionResult.message.nonEmptyTrimmedValue
                ?? "The quit action did not complete."
            return DexterActionVerificationReport(
                status: .failed,
                summary: "Verification failed: \(runtimeMessage)",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription,
                confidence: 0.9,
                evidence: evidence,
                reason: "Quit failed at execution time and the application is still running."
            )
        }

        DexterActionDiagnosticLog.verify("result=failed")
        let notFrontmostOnlyHint = launchSignals.isApplicationFrontmost
            ? ""
            : " Being in the background does not count as quit success."
        return DexterActionVerificationReport(
            status: .failed,
            summary:
                "Verification failed: \(intendedApplicationName) is still running after the quit action.\(notFrontmostOnlyHint)",
            expectedStateDescription: expectedStateDescription,
            observedStateDescription: observedStateDescription,
            confidence: 0.95,
            evidence: evidence,
            reason:
                "OpenClaw reported dispatch success, but the application process is still active. Dexter does not treat runtime success as task success."
        )
    }

    private static func quitObservedStateDescription(from signals: DexterOpenApplicationVerificationSignals) -> String {
        let bundle = signals.observedRunningBundleIdentifier ?? "none"
        let name = signals.observedRunningApplicationName ?? "unknown"
        return "running=\(signals.isApplicationRunning), visible=\(signals.hasVisibleWindow), frontmost=\(signals.isApplicationFrontmost), process=\(name) (\(bundle))."
    }

    private static func quitEvidenceLines(from signals: DexterOpenApplicationVerificationSignals) -> [String] {
        [
            "process_running=\(signals.isApplicationRunning)",
            "frontmost=\(signals.isApplicationFrontmost)",
            "visible_window=\(signals.hasVisibleWindow)",
            "observed_name=\(signals.observedRunningApplicationName ?? "none")",
            "observed_bundle=\(signals.observedRunningBundleIdentifier ?? "none")",
        ]
    }

    private static func verifyClick(
        action: DexterAction,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let expectedStateDescription = "The UI should change after clicking \(action.parameters["label"] ?? "the target")."

        guard observationAfter.hasAccessibilityObservation else {
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "Dexter could not verify the click because Accessibility observation was unavailable.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: "Window state before and after could not be compared."
            )
        }

        let valueBefore = observationBefore.pointerElementValueDescription ?? ""
        let valueAfter = observationAfter.pointerElementValueDescription ?? ""
        let titleBefore = observationBefore.pointerElementTitle ?? ""
        let titleAfter = observationAfter.pointerElementTitle ?? ""

        if !valueBefore.isEmpty || !valueAfter.isEmpty {
            let observedStateDescription =
                "Accessibility value at pointer changed from \"\(valueBefore)\" to \"\(valueAfter)\"."
            if valueBefore != valueAfter && !valueAfter.isEmpty {
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "Verified: the control's state at your pointer changed after the click.",
                    expectedStateDescription: expectedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }
        }

        if titleBefore != titleAfter && !titleAfter.isEmpty {
            let observedStateDescription =
                "Accessibility title at pointer changed from \"\(titleBefore)\" to \"\(titleAfter)\"."
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "Dexter saw the control label at your pointer change after the click, but could not confirm the intended state.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        let windowTitleBefore = observationBefore.activeWindowTitle ?? ""
        let windowTitleAfter = observationAfter.activeWindowTitle ?? ""
        let observedStateDescription = "Window title changed from \"\(windowTitleBefore)\" to \"\(windowTitleAfter)\"."

        if let expectedWindowTitleAfter = action.parameters["expectedWindowTitleAfter"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !expectedWindowTitleAfter.isEmpty {
            if windowTitleAfter == expectedWindowTitleAfter {
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "Verified: the window title matches the expected state after the click.",
                    expectedStateDescription: "Window title should be \"\(expectedWindowTitleAfter)\".",
                    observedStateDescription: observedStateDescription
                )
            }

            return DexterActionVerificationReport(
                status: .failed,
                summary: executionResult.reportedSuccess
                    ? "Verification failed: the runtime reported success, but the window title is \"\(windowTitleAfter)\" instead of \"\(expectedWindowTitleAfter)\"."
                    : "Verification failed: the window title did not reach the expected state after the click.",
                expectedStateDescription: "Window title should be \"\(expectedWindowTitleAfter)\".",
                observedStateDescription: observedStateDescription
            )
        }

        if windowTitleBefore != windowTitleAfter && !windowTitleAfter.isEmpty {
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "Dexter saw the active window change after the click, but could not confirm the intended control state.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        return DexterActionVerificationReport(
            status: executionResult.reportedSuccess ? .unavailable : .failed,
            summary: executionResult.reportedSuccess
                ? "Dexter could not confirm a UI change after the click; the window title stayed the same."
                : "Verification failed: the click did not change the observed window state.",
            expectedStateDescription: expectedStateDescription,
            observedStateDescription: observedStateDescription
        )
    }

    private static func verifyTypeText(
        action: DexterAction,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let intendedFixText = action.parameters["text"] ?? ""
        let expectedStateDescription = "The approved fix text should be available to paste into the editor."

        let pasteboardMatchesFix = NSPasteboard.general.string(forType: .string) == intendedFixText
        let didAttemptPaste = executionResult.rawOutput == "pasted"
        let observedApplicationName = observationAfter.activeApplicationLocalizedName ?? "unknown application"
        let observedBundleIdentifier = observationAfter.activeApplicationBundleIdentifier ?? ""
        let isVisualStudioCodeFrontmost = applicationNamesMatch(
            intendedName: DexterDemoApplicationNames.visualStudioCode,
            observedName: observedApplicationName
        ) || applicationNamesMatch(
            intendedName: DexterDemoApplicationNames.visualStudioCode,
            bundleIdentifier: observedBundleIdentifier
        )

        let observedStateDescription =
            "Frontmost: \(observedApplicationName). Clipboard matches fix: \(pasteboardMatchesFix). Paste attempted: \(didAttemptPaste)."

        if didAttemptPaste && isVisualStudioCodeFrontmost {
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "Dexter pasted the proposed fix into Visual Studio Code, but could not independently confirm the editor content changed.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if pasteboardMatchesFix && isVisualStudioCodeFrontmost {
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "The fix is on the clipboard and VS Code is frontmost. Press Command+V if the line did not update.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if pasteboardMatchesFix {
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "The fix was copied to the clipboard, but VS Code is not frontmost. Focus VS Code and paste.",
                expectedStateDescription: expectedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        return DexterActionVerificationReport(
            status: .failed,
            summary: executionResult.reportedSuccess
                ? "Verification failed: the clipboard does not contain the expected fix text."
                : executionResult.message,
            expectedStateDescription: expectedStateDescription,
            observedStateDescription: observedStateDescription
        )
    }

    private static func verifyWithRuntimeHintOnly(
        action: DexterAction,
        executionResult: AgentActionResult,
        observationAfter: DexterActionObservationSnapshot
    ) -> DexterActionVerificationReport {
        let observedStateDescription = observationAfter.activeApplicationLocalizedName.map { "Frontmost application: \($0)." }
            ?? "No frontmost application observation."

        if executionResult.reportedSuccess {
            return DexterActionVerificationReport(
                status: .unavailable,
                summary: "Dexter cannot independently verify \(action.type.rawValue) yet; runtime dispatch alone is not treated as success.",
                expectedStateDescription: action.humanReadableDescription,
                observedStateDescription: observedStateDescription,
                confidence: 0.15,
                evidence: ["runtime_reported_success=true", "independent_probe=unavailable"],
                reason: "No independent observation probe is implemented for this action type."
            )
        }

        return DexterActionVerificationReport(
            status: .failed,
            summary: executionResult.message,
            expectedStateDescription: action.humanReadableDescription,
            observedStateDescription: observedStateDescription
        )
    }

    private static func applicationNamesMatch(intendedName: String, observedName: String) -> Bool {
        normalizeApplicationName(intendedName) == normalizeApplicationName(observedName)
    }

    private static func applicationNamesMatch(intendedName: String, bundleIdentifier: String) -> Bool {
        let normalizedIntended = normalizeApplicationName(intendedName)
        let normalizedBundle = bundleIdentifier.lowercased()
        if normalizedBundle.contains(normalizedIntended) {
            return true
        }
        if normalizedIntended == "safari" && normalizedBundle == "com.apple.safari" {
            return true
        }
        if normalizedIntended == "calculator" && normalizedBundle == "com.apple.calculator" {
            return true
        }
        if normalizedIntended == "whatsapp" && normalizedBundle.contains("whatsapp") {
            return true
        }
        if normalizedIntended.contains("visual studio code") && normalizedBundle == "com.microsoft.vscode" {
            return true
        }
        return false
    }

    private static func normalizeApplicationName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
