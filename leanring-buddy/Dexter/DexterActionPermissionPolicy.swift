//
//  DexterActionPermissionPolicy.swift
//  leanring-buddy
//

import Foundation

struct DexterActionPermissionDecision: Equatable {
    let isAllowed: Bool
    let message: String
    let requiresAccessibilityPermission: Bool
    let requiresScreenRecordingPermission: Bool
}

enum DexterActionRuntimeAllowlist {
    /// Actions the composite agent runtime can execute in the hackathon demo.
    static func isRuntimeExecutionSupported(_ action: DexterAction) -> Bool {
        let agentRequest = DexterActionAgentRequestMapper.agentActionRequest(for: action)
        if MacDexterRuntimeAllowlist.isSupported(agentRequest) {
            return true
        }
        if DexterRegisteredToolLocalExecution.isLocallyExecuted(agentRequest) {
            return true
        }
        if OpenClawRuntimeAllowlist.isDexterSupportedAction(agentRequest) {
            return OpenClawLocalEnvironment().openClawExecutableURL != nil
        }
        return false
    }
}

extension PermissionManager {
    func evaluateComputerActionPermission(
        _ action: DexterAction,
        hasPersistedScreenContentGrant: Bool = false
    ) -> DexterActionPermissionDecision {
        let snapshot = currentPermissionSnapshot(hasPersistedScreenContentGrant: hasPersistedScreenContentGrant)

        if !DexterActionRuntimeAllowlist.isRuntimeExecutionSupported(action) {
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "Dexter does not run \(action.type.rawValue) actions yet. Only approved low-risk actions are enabled.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )
        }

        if action.parameters["command"] != nil && action.parameters["commandTemplate"] == nil {
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "Raw shell commands are not allowed. Dexter only runs approved command templates.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )
        }

        switch action.type {
        case .inspectScreen, .explainContent, .listRunningApplications:
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Read-only inspection does not require computer execution.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .openApplication, .focusApplication, .quitApplication:
            let applicationName = action.parameters["applicationName"] ?? ""
            guard !applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Dexter needs an application name before it can change application state.",
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
            let approvalMessage: String
            switch action.type {
            case .focusApplication:
                approvalMessage = "Dexter approved focusing \(applicationName)."
            case .quitApplication:
                approvalMessage = "Dexter approved quitting \(applicationName)."
            default:
                approvalMessage = "Dexter approved opening \(applicationName)."
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: approvalMessage,
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .openURL, .navigate:
            if action.parameters["browserAction"] != nil {
                return DexterActionPermissionDecision(
                    isAllowed: true,
                    message: "Dexter approved the browser action.",
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
            if action.parameters["uiDestination"]?.nonEmptyTrimmedValue != nil {
                if !snapshot.hasAccessibilityPermission {
                    return DexterActionPermissionDecision(
                        isAllowed: false,
                        message: "Accessibility permission is required before Dexter can open items in the application UI.",
                        requiresAccessibilityPermission: true,
                        requiresScreenRecordingPermission: false
                    )
                }
                return DexterActionPermissionDecision(
                    isAllowed: true,
                    message: "Dexter approved opening a UI destination in the application.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "Opening URLs and navigation actions are not enabled in Dexter yet.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .typeText:
            if !snapshot.hasAccessibilityPermission {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Accessibility permission is required before Dexter can apply a text fix.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            if action.parameters["text"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "TypeText requires non-empty fix text from the teaching step.",
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved applying the proposed code fix (paste / type).",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .click:
            if !snapshot.hasAccessibilityPermission {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Accessibility permission is required before Dexter can click the control under your pointer.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            let xCoordinate = action.parameters["x"] ?? ""
            let yCoordinate = action.parameters["y"] ?? ""
            let hasScreenCoordinates = Double(xCoordinate) != nil && Double(yCoordinate) != nil
            let hasSemanticElementReference = action.parameters["elementRef"]?.nonEmptyTrimmedValue != nil
            guard hasScreenCoordinates || hasSemanticElementReference else {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Pointer click is missing screen coordinates.",
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved one click at the pointer location you indicated.",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .keyboardShortcut:
            if !snapshot.hasAccessibilityPermission {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Accessibility permission is required before Dexter can drive UI input actions.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            let shortcut = action.parameters["shortcut"] ?? action.parameters["keys"] ?? ""
            guard !shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Keyboard shortcut actions require a non-empty shortcut description.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved the keyboard shortcut through the computer runtime.",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .select:
            if !snapshot.hasAccessibilityPermission {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Accessibility permission is required before Dexter can drive UI input actions.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "Select actions are not enabled in Dexter yet.",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .scroll:
            if !snapshot.hasAccessibilityPermission {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Accessibility permission is required before Dexter can scroll at the pointer.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved scrolling through the computer runtime.",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .runTask:
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "RunTask is not enabled for unrestricted execution in Dexter.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .fileOperation:
            let fileAction = action.parameters["fileAction"] ?? ""
            if let path = action.parameters["path"],
               case .rejected(let reason) = DexterApprovedFilePathPolicy.evaluate(path: path) {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: reason,
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved file \(fileAction) within approved folders.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .terminalOperation:
            let terminalAction = action.parameters["terminalAction"] ?? ""
            switch DexterTerminalCommandPolicy.resolve(terminalAction: terminalAction, parameters: action.parameters) {
            case .rejected(let reason):
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: reason,
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            case .approved(_, _, _, let readOnly):
                return DexterActionPermissionDecision(
                    isAllowed: true,
                    message: readOnly
                        ? "Dexter approved read-only terminal inspection."
                        : "Dexter approved structured terminal execution.",
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
        }
    }
}
