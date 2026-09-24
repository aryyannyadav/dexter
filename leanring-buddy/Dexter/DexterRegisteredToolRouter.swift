//
//  DexterRegisteredToolRouter.swift
//  leanring-buddy
//

import Foundation

enum DexterRegisteredToolRouter {
    static func toolInvocation(for proposal: DexterRegisteredToolProposal) -> DexterToolInvocation? {
        guard let definition = DexterToolRegistryCatalog.definition(for: proposal.toolName) else {
            return nil
        }

        switch definition.name {
        case .applicationLaunch:
            guard let applicationName = proposal.parameters["applicationName"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .launchApplication,
                actionIdentifier: DexterActionType.openApplication.rawValue,
                parameters: ["applicationName": applicationName]
            )
        case .applicationQuit:
            guard let applicationName = proposal.parameters["applicationName"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .quitApplication,
                actionIdentifier: DexterActionType.quitApplication.rawValue,
                parameters: ["applicationName": applicationName]
            )
        case .applicationFocus:
            guard let applicationName = proposal.parameters["applicationName"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .focusApplication,
                actionIdentifier: DexterActionType.focusApplication.rawValue,
                parameters: ["applicationName": applicationName]
            )
        case .mouseClick:
            guard let x = proposal.parameters["x"], let y = proposal.parameters["y"] else { return nil }
            var parameters = ["x": x, "y": y]
            if let label = proposal.parameters["label"] { parameters["label"] = label }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .click,
                actionIdentifier: DexterActionType.click.rawValue,
                parameters: parameters
            )
        case .keyboardType:
            guard let text = proposal.parameters["text"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .typeText,
                actionIdentifier: DexterActionType.typeText.rawValue,
                parameters: ["text": text]
            )
        case .keyboardPress:
            guard let keys = proposal.parameters["keys"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .keyPress,
                actionIdentifier: DexterActionType.keyboardShortcut.rawValue,
                parameters: ["keys": keys]
            )
        case .browserOpen:
            guard let url = proposal.parameters["url"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.openURL.rawValue,
                parameters: ["url": url, "browserAction": "open"]
            )
        case .browserNavigate:
            guard let url = proposal.parameters["url"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.navigate.rawValue,
                parameters: ["url": url, "destination": url, "browserAction": "navigate"]
            )
        case .browserSearch:
            guard let query = proposal.parameters["query"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.navigate.rawValue,
                parameters: ["query": query, "browserAction": "search"]
            )
        case .browserClick:
            guard let x = proposal.parameters["x"], let y = proposal.parameters["y"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.click.rawValue,
                parameters: ["x": x, "y": y, "browserAction": "click"]
            )
        case .browserType:
            guard let text = proposal.parameters["text"] else { return nil }
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.typeText.rawValue,
                parameters: ["text": text, "browserAction": "type"]
            )
        case .browserRead:
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.navigate.rawValue,
                parameters: ["browserAction": "read"]
            )
        case .browserBack:
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.navigate.rawValue,
                parameters: ["browserAction": "back"]
            )
        case .browserForward:
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .browserInteraction,
                actionIdentifier: DexterActionType.navigate.rawValue,
                parameters: ["browserAction": "forward"]
            )
        case .screenObserve:
            return DexterToolInvocation(
                registeredToolName: definition.name.rawValue,
                toolKind: .screenObservation,
                actionIdentifier: DexterActionType.inspectScreen.rawValue,
                parameters: [:]
            )
        case .fileSearch:
            guard let query = proposal.parameters["query"] else { return nil }
            var parameters = ["fileAction": "search", "query": query]
            if let searchRoot = proposal.parameters["searchRoot"] { parameters["searchRoot"] = searchRoot }
            return fileInvocation(definition: definition, parameters: parameters)
        case .fileRead:
            guard let path = proposal.parameters["path"] else { return nil }
            return fileInvocation(definition: definition, parameters: ["fileAction": "read", "path": path])
        case .fileCreate:
            guard let path = proposal.parameters["path"] else { return nil }
            var parameters = ["fileAction": "create", "path": path]
            if let content = proposal.parameters["content"] { parameters["content"] = content }
            return fileInvocation(definition: definition, parameters: parameters)
        case .fileWrite:
            guard let path = proposal.parameters["path"], let content = proposal.parameters["content"] else { return nil }
            return fileInvocation(
                definition: definition,
                parameters: ["fileAction": "write", "path": path, "content": content]
            )
        case .fileMove:
            guard let path = proposal.parameters["path"], let destinationPath = proposal.parameters["destinationPath"] else { return nil }
            return fileInvocation(
                definition: definition,
                parameters: ["fileAction": "move", "path": path, "destinationPath": destinationPath]
            )
        case .fileRename:
            guard let path = proposal.parameters["path"], let newName = proposal.parameters["newName"] else { return nil }
            return fileInvocation(
                definition: definition,
                parameters: ["fileAction": "rename", "path": path, "newName": newName]
            )
        case .fileDelete:
            guard let path = proposal.parameters["path"] else { return nil }
            return fileInvocation(definition: definition, parameters: ["fileAction": "delete", "path": path])
        case .terminalInspect:
            return terminalInvocation(definition: definition, terminalAction: "inspect", proposal: proposal)
        case .terminalRun:
            return terminalInvocation(definition: definition, terminalAction: "run", proposal: proposal)
        case .terminalCaptureOutput:
            return terminalInvocation(definition: definition, terminalAction: "captureOutput", proposal: proposal)
        case .screenCapture:
            return nil
        }
    }

    private static func fileInvocation(
        definition: DexterRegisteredToolDefinition,
        parameters: [String: String]
    ) -> DexterToolInvocation {
        DexterToolInvocation(
            registeredToolName: definition.name.rawValue,
            toolKind: .fileOperation,
            actionIdentifier: DexterActionType.fileOperation.rawValue,
            parameters: parameters
        )
    }

    private static func terminalInvocation(
        definition: DexterRegisteredToolDefinition,
        terminalAction: String,
        proposal: DexterRegisteredToolProposal
    ) -> DexterToolInvocation? {
        guard let commandTemplate = proposal.parameters["commandTemplate"] else { return nil }
        var parameters: [String: String] = [
            "terminalAction": terminalAction,
            "commandTemplate": commandTemplate
        ]
        if let pathArgument = proposal.parameters["pathArgument"] { parameters["pathArgument"] = pathArgument }
        if let workingDirectory = proposal.parameters["workingDirectory"] { parameters["workingDirectory"] = workingDirectory }
        if let expectedOutputContains = proposal.parameters["expectedOutputContains"] {
            parameters["expectedOutputContains"] = expectedOutputContains
        }
        return DexterToolInvocation(
            registeredToolName: definition.name.rawValue,
            toolKind: .terminalOperation,
            actionIdentifier: DexterActionType.terminalOperation.rawValue,
            parameters: parameters
        )
    }

    static func validateParameters(
        for definition: DexterRegisteredToolDefinition,
        proposal: DexterRegisteredToolProposal
    ) -> DexterToolRegistryValidationError? {
        if DexterRegisteredToolRouter.toolInvocation(for: proposal) != nil {
            return nil
        }
        return .invalidParameters("Parameters do not satisfy schema for \(definition.name.rawValue).")
    }

    static func validateExecutionPolicy(proposal: DexterRegisteredToolProposal) -> String? {
        if proposal.parameters["command"] != nil && proposal.parameters["commandTemplate"] == nil {
            return "Raw shell commands are not allowed. Use commandTemplate with an approved template id."
        }

        guard let definition = DexterToolRegistryCatalog.definition(for: proposal.toolName) else {
            return nil
        }

        switch definition.name {
        case .terminalInspect, .terminalRun, .terminalCaptureOutput:
            let terminalAction: String
            switch definition.name {
            case .terminalInspect: terminalAction = "inspect"
            case .terminalRun: terminalAction = "run"
            case .terminalCaptureOutput: terminalAction = "captureOutput"
            default: terminalAction = "inspect"
            }
            switch DexterTerminalCommandPolicy.resolve(terminalAction: terminalAction, parameters: proposal.parameters) {
            case .rejected(let reason):
                return reason
            case .approved:
                return nil
            }
        case .fileSearch, .fileRead, .fileCreate, .fileWrite, .fileMove, .fileRename, .fileDelete:
            if let path = proposal.parameters["path"] {
                if case .rejected(let reason) = DexterApprovedFilePathPolicy.evaluate(path: path) {
                    return reason
                }
            }
            if let destinationPath = proposal.parameters["destinationPath"] {
                if case .rejected(let reason) = DexterApprovedFilePathPolicy.evaluate(path: destinationPath) {
                    return reason
                }
            }
            return nil
        default:
            return nil
        }
    }
}
