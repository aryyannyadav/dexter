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
        return MacDexterRuntimeAllowlist.isSupported(agentRequest) || LegacyOpenClawRuntimeAllowlist.isSupported(agentRequest)
    }
}

enum LegacyOpenClawRuntimeAllowlist {
    static func isSupported(_ actionRequest: AgentActionRequest) -> Bool {
        actionRequest.actionIdentifier == DexterActionType.openApplication.rawValue
            && actionRequest.parameters["applicationName"] == "Safari"
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

        switch action.type {
        case .inspectScreen, .explainContent:
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Read-only inspection does not require computer execution.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .openApplication:
            let applicationName = action.parameters["applicationName"] ?? ""
            guard DexterDemoApplicationNames.isAllowlistedOpenApplication(applicationName) else {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Dexter only allows opening approved demo applications (VS Code, Safari).",
                    requiresAccessibilityPermission: false,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved opening \(applicationName).",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .openURL, .navigate:
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
            guard Double(xCoordinate) != nil, Double(yCoordinate) != nil else {
                return DexterActionPermissionDecision(
                    isAllowed: false,
                    message: "Pointer click is missing screen coordinates. Point at the control and try again.",
                    requiresAccessibilityPermission: true,
                    requiresScreenRecordingPermission: false
                )
            }
            return DexterActionPermissionDecision(
                isAllowed: true,
                message: "Dexter approved one click at the pointer location you indicated.",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .keyboardShortcut, .select:
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
                message: "UI input actions are not enabled in Dexter yet.",
                requiresAccessibilityPermission: true,
                requiresScreenRecordingPermission: false
            )

        case .scroll:
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "Scroll actions are not enabled in Dexter yet.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )

        case .runTask:
            return DexterActionPermissionDecision(
                isAllowed: false,
                message: "RunTask is not enabled for unrestricted execution in Dexter.",
                requiresAccessibilityPermission: false,
                requiresScreenRecordingPermission: false
            )
        }
    }
}
