//
//  DexterOpenApplicationVerification.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

struct DexterOpenApplicationVerificationSignals: Equatable {
    let isApplicationRunning: Bool
    let isApplicationFrontmost: Bool
    let hasVisibleWindow: Bool
    let observedRunningApplicationName: String?
    let observedRunningBundleIdentifier: String?
}

enum DexterOpenApplicationVerification {
    @MainActor
    static func signals(forApplicationName intendedApplicationName: String) -> DexterOpenApplicationVerificationSignals {
        let runningApplicationMatch = matchingRunningApplication(named: intendedApplicationName)
        let bundleMatchedRunningApplication = runningApplicationMatch
            ?? runningApplicationMatchingInstalledBundle(named: intendedApplicationName)

        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let isFrontmost = applicationNamesMatch(
            intendedName: intendedApplicationName,
            runningApplication: frontmostApplication
        )

        let bundleIdentifier = bundleMatchedRunningApplication?.bundleIdentifier
        let hasVisibleWindow = bundleIdentifier.map { hasOnScreenWindow(forBundleIdentifier: $0) } ?? false
        let isApplicationRunning = bundleMatchedRunningApplication != nil
            && bundleMatchedRunningApplication?.isTerminated == false

        return DexterOpenApplicationVerificationSignals(
            isApplicationRunning: isApplicationRunning,
            isApplicationFrontmost: isFrontmost,
            hasVisibleWindow: hasVisibleWindow,
            observedRunningApplicationName: bundleMatchedRunningApplication?.localizedName,
            observedRunningBundleIdentifier: bundleIdentifier
        )
    }

    @MainActor
    private static func runningApplicationMatchingInstalledBundle(named intendedApplicationName: String) -> NSRunningApplication? {
        guard let applicationURL = DexterInstalledApplicationLauncher.resolveApplicationURL(named: intendedApplicationName),
              let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier else {
            return nil
        }

        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })
    }

    @MainActor
    private static func matchingRunningApplication(named intendedApplicationName: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { runningApplication in
            applicationNamesMatch(intendedName: intendedApplicationName, runningApplication: runningApplication)
        }
    }

    @MainActor
    private static func applicationNamesMatch(
        intendedName: String,
        runningApplication: NSRunningApplication?
    ) -> Bool {
        guard let runningApplication else { return false }
        let localizedName = runningApplication.localizedName ?? ""
        if normalizeApplicationName(intendedName) == normalizeApplicationName(localizedName) {
            return true
        }
        if let bundleIdentifier = runningApplication.bundleIdentifier {
            return applicationNamesMatch(intendedName: intendedName, bundleIdentifier: bundleIdentifier)
        }
        return false
    }

    private static func applicationNamesMatch(intendedName: String, bundleIdentifier: String) -> Bool {
        if DexterApplicationReferenceResolver.bundleIdentifierMatches(
            userInput: intendedName,
            bundleIdentifier: bundleIdentifier
        ) {
            return true
        }
        let normalizedIntended = normalizeApplicationName(intendedName)
        let normalizedBundle = bundleIdentifier.lowercased()
        return !normalizedIntended.isEmpty && normalizedBundle.contains(normalizedIntended)
    }

    private static func normalizeApplicationName(_ name: String) -> String {
        DexterApplicationReferenceResolver.normalizeApplicationName(name)
    }

    private static func hasOnScreenWindow(forBundleIdentifier bundleIdentifier: String) -> Bool {
        guard let runningApplication = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return false
        }

        let processIdentifier = runningApplication.processIdentifier
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return runningApplication.activationPolicy == .regular
        }

        for windowInfo in windowInfoList {
            guard let ownerProcessIdentifier = windowInfo[kCGWindowOwnerPID as String] as? Int else { continue }
            if ownerProcessIdentifier == processIdentifier {
                let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
                if layer == 0 {
                    return true
                }
            }
        }

        return runningApplication.activationPolicy == .regular
    }
}
