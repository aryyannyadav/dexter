//
//  DexterActionVerificationEngine.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterActionVerificationStatus: String, Equatable {
    case success = "SUCCESS"
    case failed = "FAILED"
    case uncertain = "UNCERTAIN"
}

struct DexterActionVerificationReport: Equatable {
    let status: DexterActionVerificationStatus
    let summary: String
    let intendedStateDescription: String
    let observedStateDescription: String
}

enum DexterActionVerificationEngine {
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

    private static func verifyOpenApplication(
        action: DexterAction,
        observationAfter: DexterActionObservationSnapshot,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let intendedApplicationName = action.parameters["applicationName"] ?? "the application"
        let intendedStateDescription = "\(intendedApplicationName) should be the frontmost application."

        guard observationAfter.hasAccessibilityObservation else {
            return DexterActionVerificationReport(
                status: .uncertain,
                summary: "Dexter could not confirm whether \(intendedApplicationName) opened because Accessibility observation was unavailable.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: "Frontmost application could not be read."
            )
        }

        let observedApplicationName = observationAfter.activeApplicationLocalizedName ?? "unknown application"
        let observedBundleIdentifier = observationAfter.activeApplicationBundleIdentifier ?? "unknown bundle"
        let observedStateDescription = "Frontmost application is \(observedApplicationName) (\(observedBundleIdentifier))."

        if applicationNamesMatch(intendedName: intendedApplicationName, observedName: observedApplicationName)
            || applicationNamesMatch(intendedName: intendedApplicationName, bundleIdentifier: observedBundleIdentifier) {
            return DexterActionVerificationReport(
                status: .success,
                summary: "Verified: \(intendedApplicationName) is the frontmost application.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        let runtimeClaimedSuccess = executionResult.reportedSuccess
        let failureSummary = runtimeClaimedSuccess
            ? "Verification failed: the runtime reported success, but \(observedApplicationName) is frontmost instead of \(intendedApplicationName)."
            : "Verification failed: \(intendedApplicationName) is not the frontmost application."

        return DexterActionVerificationReport(
            status: .failed,
            summary: failureSummary,
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
                status: .uncertain,
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
                    status: .success,
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
                status: .uncertain,
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
                    status: .success,
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
                status: .uncertain,
                summary: "Dexter saw the active window change after the click, but could not confirm the intended control state.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        return DexterActionVerificationReport(
            status: executionResult.reportedSuccess ? .uncertain : .failed,
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
                status: .uncertain,
                summary: "Dexter pasted the proposed fix into Visual Studio Code, but could not independently confirm the editor content changed.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if pasteboardMatchesFix && isVisualStudioCodeFrontmost {
            return DexterActionVerificationReport(
                status: .uncertain,
                summary: "The fix is on the clipboard and VS Code is frontmost. Press Command+V if the line did not update.",
                intendedStateDescription: intendedStateDescription,
                observedStateDescription: observedStateDescription
            )
        }

        if pasteboardMatchesFix {
            return DexterActionVerificationReport(
                status: .uncertain,
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
                status: .uncertain,
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
        if normalizedIntended.contains("visual studio code") && normalizedBundle == "com.microsoft.vscode" {
            return true
        }
        return false
    }

    private static func normalizeApplicationName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
