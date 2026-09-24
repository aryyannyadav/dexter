//
//  MacDexterAgentRuntimeAdapter.swift
//  leanring-buddy
//
//  Reliable allowlisted actions for live demos (NSWorkspace + paste). OpenClaw remains optional fallback.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

final class MacDexterAgentRuntimeAdapter: AgentRuntime {
    let runtimeName = "MacDexter"

    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    func isAvailable() -> Bool {
        true
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue:
            return try await executeOpenApplication(actionRequest)
        case DexterActionType.typeText.rawValue:
            return try executeTypeText(actionRequest)
        case DexterActionType.click.rawValue:
            return try executeClick(actionRequest)
        default:
            throw AgentRuntimeError.unsupportedAction(
                "MacDexter runtime only supports approved OpenApplication, TypeText, and pointer Click demo actions."
            )
        }
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        AgentActionCancellationResult(didCancel: false, message: "MacDexter actions are instantaneous.")
    }

    private func executeOpenApplication(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        let applicationName = actionRequest.parameters["applicationName"] ?? ""
        currentExecutionStatus = .running

        let didLaunch = await MainActor.run {
            launchApplication(named: applicationName)
        }

        currentExecutionStatus = didLaunch ? .succeeded : .failed
        if didLaunch {
            return AgentActionResult(
                reportedSuccess: true,
                message: "Launched \(applicationName).",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: nil
            )
        }

        let failureMessage = DexterInstalledApplicationLauncher.isApplicationInstalled(named: applicationName)
            ? "I couldn't open \(applicationName)."
            : "\(applicationName) isn't installed on this Mac."

        return AgentActionResult(
            reportedSuccess: false,
            message: failureMessage,
            executionStatus: .failed,
            runtimeTaskIdentifier: nil,
            rawOutput: nil
        )
    }

    @MainActor
    private func launchApplication(named applicationName: String) -> Bool {
        let normalizedName = applicationName.lowercased()
        if normalizedName.contains("visual studio code") || normalizedName == "vscode" || normalizedName == "code" {
            let visualStudioCodeURL = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")
            if FileManager.default.fileExists(atPath: visualStudioCodeURL.path) {
                return NSWorkspace.shared.open(visualStudioCodeURL)
            }
            return NSWorkspace.shared.launchApplication("Visual Studio Code")
        }

        if normalizedName == "safari" {
            return NSWorkspace.shared.launchApplication("Safari")
        }

        if DexterInstalledApplicationLauncher.isApplicationInstalled(named: applicationName) {
            return DexterInstalledApplicationLauncher.launchApplication(named: applicationName)
        }

        return false
    }

    private func executeClick(_ actionRequest: AgentActionRequest) throws -> AgentActionResult {
        let xCoordinate = Double(actionRequest.parameters["x"] ?? "") ?? -1
        let yCoordinate = Double(actionRequest.parameters["y"] ?? "") ?? -1
        guard xCoordinate >= 0, yCoordinate >= 0 else {
            throw AgentRuntimeError.executionFailed("Click action is missing valid screen coordinates.")
        }

        currentExecutionStatus = .running
        let clickLocation = CGPoint(x: xCoordinate, y: yCoordinate)
        let didPostClick = MacDexterMouseClickUtility.postLeftClick(atScreenLocation: clickLocation)
        currentExecutionStatus = didPostClick ? .succeeded : .failed

        if didPostClick {
            let label = actionRequest.parameters["label"] ?? "the control"
            return AgentActionResult(
                reportedSuccess: true,
                message: "Clicked \(label) at the pointer location.",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: nil,
                rawOutput: "clicked"
            )
        }

        return AgentActionResult(
            reportedSuccess: false,
            message: "Could not click at the pointer location. Grant Accessibility permission and try again.",
            executionStatus: .failed,
            runtimeTaskIdentifier: nil,
            rawOutput: nil
        )
    }

    private func executeTypeText(_ actionRequest: AgentActionRequest) throws -> AgentActionResult {
        let textToType = actionRequest.parameters["text"] ?? ""
        guard !textToType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentRuntimeError.executionFailed("TypeText action is missing text.")
        }

        currentExecutionStatus = .running
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToType, forType: .string)

        let didPaste = MacDexterKeyboardPasteUtility.postCommandVPasteIfPermitted()
        currentExecutionStatus = didPaste ? .succeeded : .succeeded

        let message = didPaste
            ? "Pasted the approved fix into the frontmost application."
            : "Copied the fix to the clipboard. Press Command+V in VS Code to apply it."

        return AgentActionResult(
            reportedSuccess: true,
            message: message,
            executionStatus: .succeeded,
            runtimeTaskIdentifier: nil,
            rawOutput: didPaste ? "pasted" : "clipboard_only"
        )
    }
}

enum MacDexterMouseClickUtility {
    static func postLeftClick(atScreenLocation locationInScreenSpace: CGPoint) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let eventSource = CGEventSource(stateID: .hidSystemState)
        let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: locationInScreenSpace,
            mouseButton: .left
        )
        let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: locationInScreenSpace,
            mouseButton: .left
        )
        mouseDown?.post(tap: .cghidEventTap)
        usleep(80_000)
        mouseUp?.post(tap: .cghidEventTap)
        return true
    }
}

enum MacDexterKeyboardPasteUtility {
    static func postCommandVPasteIfPermitted() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let source = CGEventSource(stateID: .combinedSessionState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        commandDown?.flags = .maskCommand

        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        commandDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
        return true
    }
}

/// Routes computer actions through OpenClaw when the local node is connected; MacDexter handles allowlisted demo fallbacks.
final class CompositeDexterAgentRuntime: AgentRuntime {
    let runtimeName = "CompositeDexter"

    private let macRuntime: MacDexterAgentRuntimeAdapter
    private let openClawRuntime: OpenClawAgentRuntimeAdapter

    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    init(
        macRuntime: MacDexterAgentRuntimeAdapter = MacDexterAgentRuntimeAdapter(),
        openClawRuntime: OpenClawAgentRuntimeAdapter = OpenClawAgentRuntimeAdapter()
    ) {
        self.macRuntime = macRuntime
        self.openClawRuntime = openClawRuntime
    }

    func isAvailable() -> Bool {
        macRuntime.isAvailable() || openClawRuntime.isAvailable()
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        if OpenClawRuntimeAllowlist.prefersOpenClawRuntime(actionRequest),
           OpenClawRuntimeAllowlist.isDexterSupportedAction(actionRequest) {
            if openClawRuntime.isAvailable() {
                let result = try await openClawRuntime.executeAction(actionRequest)
                currentExecutionStatus = openClawRuntime.currentExecutionStatus
                return result
            }

            if MacDexterRuntimeAllowlist.isSupported(actionRequest) {
                let result = try await macRuntime.executeAction(actionRequest)
                currentExecutionStatus = macRuntime.currentExecutionStatus
                return result
            }

            return try await openClawRuntime.executeAction(actionRequest)
        }

        if MacDexterRuntimeAllowlist.isSupported(actionRequest) {
            let result = try await macRuntime.executeAction(actionRequest)
            currentExecutionStatus = macRuntime.currentExecutionStatus
            return result
        }

        guard openClawRuntime.isAvailable() else {
            throw AgentRuntimeError.unavailable
        }

        let result = try await openClawRuntime.executeAction(actionRequest)
        currentExecutionStatus = openClawRuntime.currentExecutionStatus
        return result
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        let macCancellation = await macRuntime.cancelCurrentAction()
        let openClawCancellation = await openClawRuntime.cancelCurrentAction()
        if openClawCancellation.didCancel {
            return openClawCancellation
        }
        return macCancellation
    }
}

enum MacDexterRuntimeAllowlist {
    static func isSupported(_ actionRequest: AgentActionRequest) -> Bool {
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue:
            let applicationName = actionRequest.parameters["applicationName"] ?? ""
            return DexterDemoApplicationNames.isAllowlistedOpenApplication(applicationName)
        case DexterActionType.typeText.rawValue:
            let text = actionRequest.parameters["text"] ?? ""
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case DexterActionType.click.rawValue:
            let xCoordinate = actionRequest.parameters["x"] ?? ""
            let yCoordinate = actionRequest.parameters["y"] ?? ""
            return Double(xCoordinate) != nil && Double(yCoordinate) != nil
        default:
            return false
        }
    }
}

enum DexterDemoApplicationNames {
    static let safari = "Safari"
    static let visualStudioCode = "Visual Studio Code"

    static func isAllowlistedOpenApplication(_ applicationName: String) -> Bool {
        let normalized = applicationName.lowercased()
        if normalized == safari.lowercased() { return true }
        if normalized.contains("visual studio code") || normalized == "vscode" || normalized == "code" {
            return true
        }
        return false
    }

    static func canonicalName(for userPhrase: String) -> String? {
        let normalized = userPhrase.lowercased()
        if normalized.contains("vscode") || normalized.contains("vs code") || normalized.contains("visual studio code") {
            return visualStudioCode
        }
        if normalized.contains("safari") {
            return safari
        }
        return nil
    }
}
