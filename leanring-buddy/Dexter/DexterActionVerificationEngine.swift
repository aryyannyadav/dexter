//
//  DexterActionVerificationEngine.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterActionVerificationStatus: String, Equatable {
    case verified = "VERIFIED"
    case partiallyVerified = "PARTIALLY_VERIFIED"
    case notVerified = "NOT_VERIFIED"
    case failed = "FAILED"
}

struct DexterActionVerificationReport: Equatable {
    let status: DexterActionVerificationStatus
    let summary: String
    let intendedStateDescription: String
    let observedStateDescription: String
}

enum DexterActionVerificationEngine {
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
            return verifyClick(
                action: action,
                observationBefore: observationBefore,
                observationAfter: observationAfter,
                executionResult: executionResult
            )

        case .typeText:
            return verifyTypeText(
                action: action,
                observationAfter: observationAfter,
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
        let intendedStateDescription = requireFrontmost
            ? "\(intendedApplicationName) should be running and frontmost."
            : "\(intendedApplicationName) should be running with a visible window when applicable."

        let launchSignals = DexterOpenApplicationVerification.signals(forApplicationName: intendedApplicationName)
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
                        intendedStateDescription: intendedStateDescription,
                        observedStateDescription: observedStateDescription
                    )
                }

                DexterActionDiagnosticLog.verify("result=partiallyVerified")
                return DexterActionVerificationReport(
                    status: .partiallyVerified,
                    summary: "\(intendedApplicationName) is running, but it isn't the frontmost window.",
                    intendedStateDescription: intendedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }

            if launchSignals.isApplicationFrontmost {
                DexterActionDiagnosticLog.verify("result=verified")
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "\(intendedApplicationName) is open.",
                    intendedStateDescription: intendedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }

            if launchSignals.hasVisibleWindow {
                DexterActionDiagnosticLog.verify("result=partiallyVerified")
                return DexterActionVerificationReport(
                    status: .partiallyVerified,
                    summary: "\(intendedApplicationName) is open, although it isn't the frontmost window.",
                    intendedStateDescription: intendedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }

            DexterActionDiagnosticLog.verify("result=partiallyVerified")
            return DexterActionVerificationReport(
                status: .partiallyVerified,
                summary: "\(intendedApplicationName) is running, but Dexter could not confirm a visible window.",
                intendedStateDescription: intendedStateDescription,
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
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        DexterActionDiagnosticLog.verify("result=failed")
        let failureSummary =
            "I sent the \(verb) action, but \(intendedApplicationName) does not appear to be running."
        return DexterActionVerificationReport(
            status: .failed,
            summary: failureSummary,
            intendedStateDescription: intendedStateDescription,
            observedStateDescription: observedStateDescription
        )
    }

    @MainActor
    private static func verifyQuitApplication(
        action: DexterAction,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let intendedApplicationName = action.parameters["applicationName"] ?? "the application"
        let intendedStateDescription = "\(intendedApplicationName) should not be running."

        let launchSignals = DexterOpenApplicationVerification.signals(forApplicationName: intendedApplicationName)
        DexterActionDiagnosticLog.verify("running=\(launchSignals.isApplicationRunning)")
        DexterActionDiagnosticLog.verify("visible=\(launchSignals.hasVisibleWindow)")
        DexterActionDiagnosticLog.verify("frontmost=\(launchSignals.isApplicationFrontmost)")

        let observedStateDescription =
            "running=\(launchSignals.isApplicationRunning), visible=\(launchSignals.hasVisibleWindow), frontmost=\(launchSignals.isApplicationFrontmost)."

        if !launchSignals.isApplicationRunning {
            DexterActionDiagnosticLog.verify("result=verified")
            return DexterActionVerificationReport(
                status: .verified,
                summary: "Done — \(intendedApplicationName) is closed.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if !executionResult.reportedSuccess {
            DexterActionDiagnosticLog.verify("result=failed")
            return DexterActionVerificationReport(
                status: .failed,
                summary: executionResult.message.nonEmptyTrimmedValue
                    ?? "I couldn't quit \(intendedApplicationName).",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        DexterActionDiagnosticLog.verify("result=failed")
        return DexterActionVerificationReport(
            status: .failed,
            summary: "I sent the quit action, but I couldn't verify that \(intendedApplicationName) actually closed.",
            intendedStateDescription: intendedStateDescription,
            observedStateDescription: observedStateDescription
        )
    }

    private static func verifyClick(
        action: DexterAction,
        observationBefore: DexterActionObservationSnapshot,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let intendedStateDescription = "The UI should change after clicking \(action.parameters["label"] ?? "the target")."

        guard observationAfter.hasAccessibilityObservation else {
            return DexterActionVerificationReport(
                status: .notVerified,
                summary: "Dexter could not verify the click because Accessibility observation was unavailable.",
                intendedStateDescription: intendedStateDescription,
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
                    intendedStateDescription: intendedStateDescription,
                    observedStateDescription: observedStateDescription
                )
            }
        }

        if titleBefore != titleAfter && !titleAfter.isEmpty {
            let observedStateDescription =
                "Accessibility title at pointer changed from \"\(titleBefore)\" to \"\(titleAfter)\"."
            return DexterActionVerificationReport(
                status: .notVerified,
                summary: "Dexter saw the control label at your pointer change after the click, but could not confirm the intended state.",
                intendedStateDescription: intendedStateDescription,
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
                    intendedStateDescription: "Window title should be \"\(expectedWindowTitleAfter)\".",
                    observedStateDescription: observedStateDescription
                )
            }

            return DexterActionVerificationReport(
                status: .failed,
                summary: executionResult.reportedSuccess
                    ? "Verification failed: the runtime reported success, but the window title is \"\(windowTitleAfter)\" instead of \"\(expectedWindowTitleAfter)\"."
                    : "Verification failed: the window title did not reach the expected state after the click.",
                intendedStateDescription: "Window title should be \"\(expectedWindowTitleAfter)\".",
                observedStateDescription: observedStateDescription
            )
        }

        if windowTitleBefore != windowTitleAfter && !windowTitleAfter.isEmpty {
            return DexterActionVerificationReport(
                status: .notVerified,
                summary: "Dexter saw the active window change after the click, but could not confirm the intended control state.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        return DexterActionVerificationReport(
            status: executionResult.reportedSuccess ? .notVerified : .failed,
            summary: executionResult.reportedSuccess
                ? "Dexter could not confirm a UI change after the click; the window title stayed the same."
                : "Verification failed: the click did not change the observed window state.",
            intendedStateDescription: intendedStateDescription,
            observedStateDescription: observedStateDescription
        )
    }

    private static func verifyTypeText(
        action: DexterAction,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let intendedFixText = action.parameters["text"] ?? ""
        let intendedStateDescription = "The approved fix text should be available to paste into the editor."

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
                status: .notVerified,
                summary: "Dexter pasted the proposed fix into Visual Studio Code, but could not independently confirm the editor content changed.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if pasteboardMatchesFix && isVisualStudioCodeFrontmost {
            return DexterActionVerificationReport(
                status: .notVerified,
                summary: "The fix is on the clipboard and VS Code is frontmost. Press Command+V if the line did not update.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if pasteboardMatchesFix {
            return DexterActionVerificationReport(
                status: .notVerified,
                summary: "The fix was copied to the clipboard, but VS Code is not frontmost. Focus VS Code and paste.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        return DexterActionVerificationReport(
            status: .failed,
            summary: executionResult.reportedSuccess
                ? "Verification failed: the clipboard does not contain the expected fix text."
                : executionResult.message,
            intendedStateDescription: intendedStateDescription,
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
                status: .notVerified,
                summary: "Dexter cannot independently verify \(action.type.rawValue) yet; treating the runtime success report as uncertain.",
                intendedStateDescription: action.humanReadableDescription,
                observedStateDescription: observedStateDescription
            )
        }

        return DexterActionVerificationReport(
            status: .failed,
            summary: executionResult.message,
            intendedStateDescription: action.humanReadableDescription,
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

private extension String {
    var nonEmptyTrimmedValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
