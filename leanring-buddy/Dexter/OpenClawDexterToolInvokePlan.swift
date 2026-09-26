//
//  OpenClawDexterToolInvokePlan.swift
//  leanring-buddy
//

import Foundation

struct OpenClawDexterToolInvokePlan: Equatable {
    let nodeCommand: String
    let parametersJSON: String
    let shouldCloseComputerActExecution: Bool
    let executionIdentifier: String
}

enum OpenClawDexterToolInvokePlanner {
    static func plan(
        toolInvocation: DexterToolInvocation,
        executionIdentifier: String,
        computerUseDescriptor: OpenClawNodeComputerUseDescriptorSnapshot,
        advertisedCommands: [String]
    ) -> OpenClawDexterToolInvokePlan? {
        switch toolInvocation.toolKind {
        case .launchApplication:
            guard let openClawApplicationToken = resolvedOpenClawApplicationToken(from: toolInvocation) else { return nil }
            guard computerUseDescriptor.advertisesComputerUseAction("launch_app") else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "launch_app",
                fields: ["app": .string(openClawApplicationToken)]
            )
        case .quitApplication:
            guard let openClawApplicationToken = resolvedOpenClawApplicationToken(from: toolInvocation) else { return nil }
            guard computerUseDescriptor.advertisesComputerUseAction("kill_app") else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "kill_app",
                fields: ["app": .string(openClawApplicationToken)]
            )
        case .focusApplication:
            if let windowRef = toolInvocation.parameters["windowRef"],
               computerUseDescriptor.advertisesComputerUseAction("bring_to_front") {
                return computerActPlan(
                    executionIdentifier: executionIdentifier,
                    actionName: "bring_to_front",
                    fields: ["windowRef": .string(windowRef)]
                )
            }
            guard let openClawApplicationToken = resolvedOpenClawApplicationToken(from: toolInvocation) else { return nil }
            if computerUseDescriptor.advertisesComputerUseAction("launch_app") {
                return computerActPlan(
                    executionIdentifier: executionIdentifier,
                    actionName: "launch_app",
                    fields: ["app": .string(openClawApplicationToken)]
                )
            }
            if computerUseDescriptor.advertisesComputerUseAction("bring_to_front") {
                return computerActPlan(
                    executionIdentifier: executionIdentifier,
                    actionName: "bring_to_front",
                    fields: ["app": .string(openClawApplicationToken)]
                )
            }
            return nil
        case .listRunningApplications:
            guard computerUseDescriptor.advertisesComputerUseAction("list_apps") else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "list_apps",
                fields: [:]
            )
        case .click:
            guard let xText = toolInvocation.parameters["x"],
                  let yText = toolInvocation.parameters["y"],
                  let xCoordinate = Double(xText),
                  let yCoordinate = Double(yText) else { return nil }
            let clickAction = DexterOpenClawComputerUsePointerCapabilities.resolvedClickAction(
                from: toolInvocation.parameters
            )
            guard computerUseDescriptor.advertisesComputerUseAction(clickAction.rawValue) else { return nil }
            var fields: [String: OpenClawComputerActJSONValue] = [
                "x": .double(xCoordinate),
                "y": .double(yCoordinate)
            ]
            if let displayFrameId = toolInvocation.parameters["displayFrameId"] {
                fields["displayFrameId"] = .string(displayFrameId)
            }
            if let observationId = toolInvocation.parameters["observationId"] {
                fields["observationId"] = .string(observationId)
            }
            if let refWidthText = toolInvocation.parameters["refWidth"],
               let refWidth = Int(refWidthText) {
                fields["refWidth"] = .int(refWidth)
            }
            if let elementRef = toolInvocation.parameters["elementRef"]?.nonEmptyTrimmedValue {
                fields["elementRef"] = .string(elementRef)
            }
            if let screenIndexText = toolInvocation.parameters["screenIndex"],
               let screenIndex = Int(screenIndexText) {
                fields["screenIndex"] = .int(screenIndex)
            }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: clickAction.rawValue,
                fields: fields
            )
        case .typeText:
            guard let text = toolInvocation.parameters["text"] else { return nil }
            guard computerUseDescriptor.advertisesComputerUseAction("type") else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "type",
                fields: ["text": .string(text)]
            )
        case .keyPress:
            let keys = toolInvocation.parameters["shortcut"]
                ?? toolInvocation.parameters["keys"]
                ?? ""
            guard !keys.isEmpty else { return nil }
            guard computerUseDescriptor.advertisesComputerUseAction("key") else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "key",
                fields: ["keys": .string(keys)]
            )
        case .scroll:
            guard computerUseDescriptor.advertisesComputerUseAction("scroll") else { return nil }
            var fields: [String: OpenClawComputerActJSONValue] = [:]
            if let direction = normalizedScrollDirection(from: toolInvocation.parameters) {
                fields["scrollDirection"] = .string(direction)
            }
            if let scrollAmount = resolvedScrollAmount(from: toolInvocation.parameters) {
                fields["scrollAmount"] = .int(scrollAmount)
            }
            if let xText = toolInvocation.parameters["x"],
               let yText = toolInvocation.parameters["y"],
               let xCoordinate = Double(xText),
               let yCoordinate = Double(yText) {
                fields["x"] = .double(xCoordinate)
                fields["y"] = .double(yCoordinate)
            }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "scroll",
                fields: fields
            )
        case .browserInteraction:
            let browserAction = toolInvocation.parameters["browserAction"] ?? "open"
            var fields: [String: String] = ["browserAction": browserAction]
            if let url = toolInvocation.parameters["url"] { fields["url"] = url }
            if let query = toolInvocation.parameters["query"] { fields["query"] = query }
            if let text = toolInvocation.parameters["text"] { fields["text"] = text }
            if let x = toolInvocation.parameters["x"] { fields["x"] = x }
            if let y = toolInvocation.parameters["y"] { fields["y"] = y }
            return OpenClawDexterToolInvokePlan(
                nodeCommand: DexterOpenClawCapabilityKind.browserProxy.rawValue,
                parametersJSON: OpenClawNodeParametersJSONBuilder.payload(
                    executionIdentifier: executionIdentifier,
                    fields: fields
                ),
                shouldCloseComputerActExecution: false,
                executionIdentifier: executionIdentifier
            )
        case .screenSnapshot, .screenObservation:
            return OpenClawDexterToolInvokePlan(
                nodeCommand: DexterOpenClawCapabilityKind.screenSnapshot.rawValue,
                parametersJSON: OpenClawNodeParametersJSONBuilder.payload(
                    executionIdentifier: executionIdentifier,
                    fields: [:]
                ),
                shouldCloseComputerActExecution: false,
                executionIdentifier: executionIdentifier
            )
        case .systemRun:
            let instruction = toolInvocation.parameters["instruction"] ?? toolInvocation.parameters["command"] ?? ""
            return OpenClawDexterToolInvokePlan(
                nodeCommand: DexterOpenClawCapabilityKind.systemRun.rawValue,
                parametersJSON: OpenClawNodeParametersJSONBuilder.payload(
                    executionIdentifier: executionIdentifier,
                    fields: ["command": instruction]
                ),
                shouldCloseComputerActExecution: false,
                executionIdentifier: executionIdentifier
            )
        case .fileOperation:
            guard let fileAction = toolInvocation.parameters["fileAction"] else { return nil }
            guard let nodeCommand = OpenClawAdvertisedFileCommandResolver.resolveNodeCommand(
                advertisedCommands: advertisedCommands,
                fileAction: fileAction
            ) else { return nil }
            var fields: [String: String] = [:]
            for (fieldKey, fieldValue) in toolInvocation.parameters where fieldKey != "fileAction" {
                fields[fieldKey] = fieldValue
            }
            fields["fileAction"] = fileAction
            return OpenClawDexterToolInvokePlan(
                nodeCommand: nodeCommand,
                parametersJSON: OpenClawNodeParametersJSONBuilder.payload(
                    executionIdentifier: executionIdentifier,
                    fields: fields
                ),
                shouldCloseComputerActExecution: false,
                executionIdentifier: executionIdentifier
            )
        case .terminalOperation:
            return nil
        }
    }

    private static func normalizedScrollDirection(from parameters: [String: String]) -> String? {
        if let direction = parameters["scrollDirection"] ?? parameters["direction"] {
            let normalized = direction.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["up", "down", "left", "right"].contains(normalized) {
                return normalized
            }
        }
        if let deltaYText = parameters["deltaY"], let deltaY = Int(deltaYText) {
            if deltaY > 0 { return "down" }
            if deltaY < 0 { return "up" }
        }
        if let deltaXText = parameters["deltaX"], let deltaX = Int(deltaXText) {
            if deltaX > 0 { return "right" }
            if deltaX < 0 { return "left" }
        }
        return nil
    }

    private static func resolvedScrollAmount(from parameters: [String: String]) -> Int? {
        if let scrollAmountText = parameters["scrollAmount"], let scrollAmount = Int(scrollAmountText) {
            return max(1, scrollAmount)
        }
        if let deltaYText = parameters["deltaY"], let deltaY = Int(deltaYText) {
            return max(1, abs(deltaY))
        }
        if let deltaXText = parameters["deltaX"], let deltaX = Int(deltaXText) {
            return max(1, abs(deltaX))
        }
        return nil
    }

    private static func resolvedOpenClawApplicationToken(from toolInvocation: DexterToolInvocation) -> String? {
        if let token = toolInvocation.parameters["openClawApplicationToken"]?.nonEmptyTrimmedValue {
            return token
        }
        return toolInvocation.parameters["applicationName"]?.nonEmptyTrimmedValue
    }

    private static func computerActPlan(
        executionIdentifier: String,
        actionName: String,
        fields: [String: OpenClawComputerActJSONValue]
    ) -> OpenClawDexterToolInvokePlan {
        OpenClawDexterToolInvokePlan(
            nodeCommand: DexterOpenClawCapabilityKind.computerAct.rawValue,
            parametersJSON: OpenClawComputerActRequestBuilder.computerActParametersJSON(
                executionIdentifier: executionIdentifier,
                actionName: actionName,
                fields: fields
            ),
            shouldCloseComputerActExecution: true,
            executionIdentifier: executionIdentifier
        )
    }
}

enum OpenClawAdvertisedFileCommandResolver {
    static func resolveNodeCommand(advertisedCommands: [String], fileAction: String) -> String? {
        let normalizedAction = fileAction.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedAction.isEmpty else { return nil }

        let dottedCandidate = "file.\(normalizedAction)"
        if advertisedCommands.contains(dottedCandidate) {
            return dottedCandidate
        }

        let registeredToolCandidate = "file.\(fileActionRegistrySuffix(for: normalizedAction))"
        if advertisedCommands.contains(registeredToolCandidate) {
            return registeredToolCandidate
        }

        if advertisedCommands.contains("file") {
            return "file"
        }
        return nil
    }

    private static func fileActionRegistrySuffix(for normalizedAction: String) -> String {
        switch normalizedAction {
        case "search": return "search"
        case "read": return "read"
        case "create": return "create"
        case "write": return "write"
        case "move": return "move"
        case "rename": return "rename"
        case "delete": return "delete"
        default: return normalizedAction
        }
    }
}

enum OpenClawNodeParametersJSONBuilder {
    static func payload(executionIdentifier: String, fields: [String: String]) -> String {
        var payload: [String: Any] = ["executionId": executionIdentifier.lowercased()]
        for (fieldKey, fieldValue) in fields {
            payload[fieldKey] = fieldValue
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}
