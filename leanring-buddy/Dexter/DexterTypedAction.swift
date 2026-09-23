//
//  DexterTypedAction.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterActionType: String, Equatable, CaseIterable {
    case inspectScreen = "InspectScreen"
    case explainContent = "ExplainContent"
    case openApplication = "OpenApplication"
    case openURL = "OpenURL"
    case click = "Click"
    case typeText = "TypeText"
    case scroll = "Scroll"
    case keyboardShortcut = "KeyboardShortcut"
    case navigate = "Navigate"
    case select = "Select"
    case runTask = "RunTask"
}

enum DexterActionRiskLevel: String, Equatable {
    case readOnly = "READ_ONLY"
    case lowRisk = "LOW_RISK"
    case moderateRisk = "MODERATE_RISK"
    case highRisk = "HIGH_RISK"
}

enum DexterActionState: String, Equatable {
    case proposed
    case awaitingConfirmation = "awaiting_confirmation"
    case approved
    case executing
    case completed
    case failed
    case cancelled
    case verificationFailed = "verification_failed"
}

/// Typed computer/browser action tracked through orchestration (not exposed as arbitrary UI execution).
struct DexterAction: Equatable, Identifiable {
    let id: UUID
    let type: DexterActionType
    let parameters: [String: String]
    let riskLevel: DexterActionRiskLevel
    let humanReadableDescription: String
    var state: DexterActionState
    let proposedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: DexterActionType,
        parameters: [String: String],
        riskLevel: DexterActionRiskLevel,
        humanReadableDescription: String,
        state: DexterActionState = .proposed,
        proposedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.riskLevel = riskLevel
        self.humanReadableDescription = humanReadableDescription
        self.state = state
        self.proposedAt = proposedAt
        self.updatedAt = updatedAt
    }

    func withState(_ state: DexterActionState, at date: Date = Date()) -> DexterAction {
        var copy = self
        copy.state = state
        copy.updatedAt = date
        return copy
    }
}

enum DexterActionFactory {
    static func inspectScreen(contextSummary: String? = nil) -> DexterAction {
        var parameters: [String: String] = [:]
        if let contextSummary { parameters["contextSummary"] = contextSummary }
        return DexterAction(
            type: .inspectScreen,
            parameters: parameters,
            riskLevel: .readOnly,
            humanReadableDescription: "Inspect what is on screen without changing anything."
        )
    }

    static func explainContent(subject: String) -> DexterAction {
        DexterAction(
            type: .explainContent,
            parameters: ["subject": subject],
            riskLevel: .readOnly,
            humanReadableDescription: "Explain \(subject) using current screen context."
        )
    }

    static func openApplication(named applicationName: String, contextSummary: String? = nil) -> DexterAction {
        var parameters = ["applicationName": applicationName]
        if let contextSummary {
            parameters["contextSummary"] = contextSummary
        }
        return DexterAction(
            type: .openApplication,
            parameters: parameters,
            riskLevel: .lowRisk,
            humanReadableDescription: "Open \(applicationName)."
        )
    }

    static func openURL(_ urlString: String) -> DexterAction {
        DexterAction(
            type: .openURL,
            parameters: ["url": urlString],
            riskLevel: .lowRisk,
            humanReadableDescription: "Open the webpage \(urlString)."
        )
    }

    static func click(x: String, y: String, label: String? = nil) -> DexterAction {
        var parameters = ["x": x, "y": y]
        if let label { parameters["label"] = label }
        return DexterAction(
            type: .click,
            parameters: parameters,
            riskLevel: .highRisk,
            humanReadableDescription: "Click at (\(x), \(y))."
        )
    }

    static func clickAtScreenLocation(_ locationInScreenSpace: CGPoint, label: String) -> DexterAction {
        let xCoordinate = String(format: "%.0f", locationInScreenSpace.x)
        let yCoordinate = String(format: "%.0f", locationInScreenSpace.y)
        return DexterAction(
            type: .click,
            parameters: [
                "x": xCoordinate,
                "y": yCoordinate,
                "label": label
            ],
            riskLevel: .highRisk,
            humanReadableDescription: "Click \(label) at your pointer location."
        )
    }

    static func typeText(_ text: String) -> DexterAction {
        DexterAction(
            type: .typeText,
            parameters: ["text": text],
            riskLevel: .moderateRisk,
            humanReadableDescription: "Type text into the focused field."
        )
    }

    static func scroll(direction: String, amount: String? = nil) -> DexterAction {
        var parameters = ["direction": direction]
        if let amount { parameters["amount"] = amount }
        return DexterAction(
            type: .scroll,
            parameters: parameters,
            riskLevel: .lowRisk,
            humanReadableDescription: "Scroll \(direction)."
        )
    }

    static func keyboardShortcut(_ shortcutDescription: String) -> DexterAction {
        DexterAction(
            type: .keyboardShortcut,
            parameters: ["shortcut": shortcutDescription],
            riskLevel: .highRisk,
            humanReadableDescription: "Press keyboard shortcut \(shortcutDescription)."
        )
    }

    static func navigate(_ destination: String) -> DexterAction {
        DexterAction(
            type: .navigate,
            parameters: ["destination": destination],
            riskLevel: .lowRisk,
            humanReadableDescription: "Navigate to \(destination)."
        )
    }

    static func select(targetDescription: String) -> DexterAction {
        DexterAction(
            type: .select,
            parameters: ["target": targetDescription],
            riskLevel: .moderateRisk,
            humanReadableDescription: "Select \(targetDescription)."
        )
    }

    static func runTask(instruction: String) -> DexterAction {
        DexterAction(
            type: .runTask,
            parameters: ["instruction": instruction],
            riskLevel: .highRisk,
            humanReadableDescription: "Run agent task: \(instruction)."
        )
    }
}

enum DexterActionAgentRequestMapper {
    static func agentActionRequest(for action: DexterAction) -> AgentActionRequest {
        AgentActionRequest(
            actionIdentifier: action.type.rawValue,
            parameters: action.parameters
        )
    }
}
