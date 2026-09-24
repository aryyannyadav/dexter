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
        executionIdentifier: String
    ) -> OpenClawDexterToolInvokePlan? {
        switch toolInvocation.toolKind {
        case .launchApplication:
            guard let applicationName = toolInvocation.parameters["applicationName"] else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "launch_app",
                fields: ["app": applicationName]
            )
        case .quitApplication:
            guard let applicationName = toolInvocation.parameters["applicationName"] else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "kill_app",
                fields: ["app": applicationName]
            )
        case .focusApplication:
            guard let applicationName = toolInvocation.parameters["applicationName"] else { return nil }
            // OpenClaw 2026.9.x focuses by re-launching/bringing the app forward via launch_app.
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "launch_app",
                fields: ["app": applicationName]
            )
        case .click:
            guard let x = toolInvocation.parameters["x"], let y = toolInvocation.parameters["y"] else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "click",
                fields: ["x": x, "y": y]
            )
        case .typeText:
            guard let text = toolInvocation.parameters["text"] else { return nil }
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "type",
                fields: ["text": text]
            )
        case .keyPress:
            let keys = toolInvocation.parameters["shortcut"]
                ?? toolInvocation.parameters["keys"]
                ?? ""
            return computerActPlan(
                executionIdentifier: executionIdentifier,
                actionName: "key_press",
                fields: ["keys": keys]
            )
        case .scroll:
            var fields: [String: String] = [:]
            if let deltaX = toolInvocation.parameters["deltaX"] { fields["deltaX"] = deltaX }
            if let deltaY = toolInvocation.parameters["deltaY"] { fields["deltaY"] = deltaY }
            if let direction = toolInvocation.parameters["direction"] { fields["direction"] = direction }
            if let x = toolInvocation.parameters["x"] { fields["x"] = x }
            if let y = toolInvocation.parameters["y"] { fields["y"] = y }
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
        case .fileOperation, .terminalOperation:
            return nil
        }
    }

    private static func computerActPlan(
        executionIdentifier: String,
        actionName: String,
        fields: [String: String]
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

enum OpenClawNodeParametersJSONBuilder {
    static func payload(executionIdentifier: String, fields: [String: String]) -> String {
        var payload: [String: Any] = ["executionId": executionIdentifier]
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
