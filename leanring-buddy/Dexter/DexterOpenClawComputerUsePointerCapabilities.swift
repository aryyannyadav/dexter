//
//  DexterOpenClawComputerUsePointerCapabilities.swift
//  leanring-buddy
//

import Foundation

enum DexterOpenClawComputerUsePointerAction: String, Equatable {
    case leftClick = "left_click"
    case rightClick = "right_click"
    case doubleClick = "double_click"
    case type = "type"
    case key = "key"
    case scroll = "scroll"
    case mouseMove = "mouse_move"
    case leftClickDrag = "left_click_drag"
}

enum DexterOpenClawComputerUsePointerCapabilities {
    static func requiredComputerUseAction(for toolKind: DexterToolKind) -> DexterOpenClawComputerUsePointerAction? {
        switch toolKind {
        case .click:
            return .leftClick
        case .typeText:
            return .type
        case .keyPress:
            return .key
        case .scroll:
            return .scroll
        default:
            return nil
        }
    }

    static func requiredComputerUseAction(
        for toolKind: DexterToolKind,
        parameters: [String: String]
    ) -> DexterOpenClawComputerUsePointerAction? {
        if toolKind == .click {
            return resolvedClickAction(from: parameters)
        }
        return requiredComputerUseAction(for: toolKind)
    }

    static func supportsToolExecution(
        toolKind: DexterToolKind,
        parameters: [String: String],
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot
    ) -> Bool {
        guard let requiredAction = requiredComputerUseAction(for: toolKind, parameters: parameters) else {
            return true
        }
        return computerUseDescriptor.advertisesComputerUseAction(requiredAction.rawValue)
    }

    static func unavailableReason(
        toolKind: DexterToolKind,
        parameters: [String: String],
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot
    ) -> DexterToolGatewayUnavailableReason? {
        guard requiredComputerUseAction(for: toolKind) != nil else { return nil }
        if supportsToolExecution(
            toolKind: toolKind,
            parameters: parameters,
            computerUseDescriptor: computerUseDescriptor
        ) {
            return nil
        }
        return .capabilityMissing(.computerAct)
    }

    static func resolvedClickAction(from parameters: [String: String]) -> DexterOpenClawComputerUsePointerAction {
        let normalizedKind = (parameters["clickKind"] ?? parameters["button"] ?? "left")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch normalizedKind {
        case "right", "right_click", "right-click":
            return .rightClick
        case "double", "double_click", "double-click":
            return .doubleClick
        default:
            return .leftClick
        }
    }
}
