//
//  DexterTool.swift
//  leanring-buddy
//
//  Typed tools Dexter executes after policy approval (models propose actions; tools execute).
//

import Foundation

/// OpenClaw node command surfaces Dexter may route through.
enum DexterOpenClawCapabilityKind: String, Equatable, CaseIterable {
    case computerAct = "computer.act"
    case screenSnapshot = "screen.snapshot"
    case browserProxy = "browser.proxy"
    case systemRun = "system.run"
    case file = "file"
    case canvas = "canvas"
    case mcp = "mcp"
    case localInference = "local-inference"
}

/// Policy-approved tool invocation (never constructed directly by the LLM).
struct DexterToolInvocation: Equatable {
    let registeredToolName: String?
    let toolKind: DexterToolKind
    let actionIdentifier: String
    let parameters: [String: String]

    init(
        registeredToolName: String? = nil,
        toolKind: DexterToolKind,
        actionIdentifier: String,
        parameters: [String: String]
    ) {
        self.registeredToolName = registeredToolName
        self.toolKind = toolKind
        self.actionIdentifier = actionIdentifier
        self.parameters = parameters
    }
}

enum DexterToolKind: Equatable {
    case launchApplication
    case quitApplication
    case focusApplication
    case listRunningApplications
    case click
    case typeText
    case keyPress
    case scroll
    case browserInteraction
    case screenSnapshot
    case screenObservation
    case systemRun
    case fileOperation
    case terminalOperation

    var requiredOpenClawCapability: DexterOpenClawCapabilityKind? {
        switch self {
        case .launchApplication, .quitApplication, .focusApplication, .listRunningApplications, .click, .typeText, .keyPress, .scroll:
            return .computerAct
        case .screenSnapshot, .screenObservation:
            return .screenSnapshot
        case .browserInteraction:
            return .browserProxy
        case .systemRun:
            return .systemRun
        case .fileOperation:
            return .file
        case .terminalOperation:
            return nil
        }
    }
}

enum DexterTool {
    static func invocation(from actionRequest: AgentActionRequest) -> DexterToolInvocation? {
        guard let toolKind = toolKind(for: actionRequest) else { return nil }
        return DexterToolInvocation(
            registeredToolName: registeredToolName(for: actionRequest, toolKind: toolKind),
            toolKind: toolKind,
            actionIdentifier: actionRequest.actionIdentifier,
            parameters: actionRequest.parameters
        )
    }

    static func toolKind(for actionRequest: AgentActionRequest) -> DexterToolKind? {
        let browserAction = actionRequest.parameters["browserAction"] ?? ""

        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue:
            return nonEmptyApplicationName(from: actionRequest) != nil ? .launchApplication : nil
        case DexterActionType.quitApplication.rawValue:
            return nonEmptyApplicationName(from: actionRequest) != nil ? .quitApplication : nil
        case DexterActionType.focusApplication.rawValue:
            return nonEmptyApplicationName(from: actionRequest) != nil ? .focusApplication : nil
        case DexterActionType.listRunningApplications.rawValue:
            return .listRunningApplications
        case DexterActionType.click.rawValue:
            if browserAction == "click" { return .browserInteraction }
            if let elementRef = actionRequest.parameters["elementRef"]?.nonEmptyTrimmedValue,
               !elementRef.isEmpty {
                return .click
            }
            let xCoordinate = actionRequest.parameters["x"] ?? ""
            let yCoordinate = actionRequest.parameters["y"] ?? ""
            return Double(xCoordinate) != nil && Double(yCoordinate) != nil ? .click : nil
        case DexterActionType.typeText.rawValue:
            if browserAction == "type" { return .browserInteraction }
            let text = actionRequest.parameters["text"] ?? ""
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .typeText
        case DexterActionType.keyboardShortcut.rawValue:
            let shortcut = actionRequest.parameters["shortcut"] ?? actionRequest.parameters["keys"] ?? ""
            return shortcut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .keyPress
        case DexterActionType.scroll.rawValue:
            return .scroll
        case DexterActionType.openURL.rawValue:
            let url = actionRequest.parameters["url"] ?? ""
            return url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .browserInteraction
        case DexterActionType.navigate.rawValue:
            if actionRequest.parameters["uiDestination"]?.nonEmptyTrimmedValue != nil {
                return .click
            }
            let url = actionRequest.parameters["url"] ?? actionRequest.parameters["destination"] ?? ""
            let query = actionRequest.parameters["query"] ?? ""
            if !browserAction.isEmpty || !url.isEmpty || !query.isEmpty {
                return .browserInteraction
            }
            return nil
        case DexterActionType.inspectScreen.rawValue:
            return .screenSnapshot
        case DexterActionType.explainContent.rawValue:
            return .screenObservation
        case DexterActionType.runTask.rawValue:
            let instruction = actionRequest.parameters["instruction"] ?? ""
            return instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .systemRun
        case DexterActionType.fileOperation.rawValue:
            let fileAction = actionRequest.parameters["fileAction"] ?? ""
            return fileAction.isEmpty ? nil : .fileOperation
        case DexterActionType.terminalOperation.rawValue:
            let terminalAction = actionRequest.parameters["terminalAction"] ?? ""
            let commandTemplate = actionRequest.parameters["commandTemplate"] ?? ""
            return terminalAction.isEmpty || commandTemplate.isEmpty ? nil : .terminalOperation
        default:
            return nil
        }
    }

    static func isOpenClawToolingSupported(_ actionRequest: AgentActionRequest) -> Bool {
        registeredToolProposal(from: actionRequest) != nil
    }

    static func registeredToolProposal(from actionRequest: AgentActionRequest) -> DexterRegisteredToolProposal? {
        guard let toolInvocation = invocation(from: actionRequest),
              let registeredToolName = toolInvocation.registeredToolName
        else {
            return nil
        }
        return DexterRegisteredToolProposal(
            toolName: registeredToolName,
            parameters: toolInvocation.parameters
        )
    }

    private static func registeredToolName(
        for actionRequest: AgentActionRequest,
        toolKind: DexterToolKind
    ) -> String? {
        if toolKind == .browserInteraction {
            return registeredBrowserToolName(for: actionRequest)
        }

        switch toolKind {
        case .launchApplication: return DexterRegisteredToolName.applicationLaunch.rawValue
        case .quitApplication: return DexterRegisteredToolName.applicationQuit.rawValue
        case .focusApplication: return DexterRegisteredToolName.applicationFocus.rawValue
        case .listRunningApplications: return DexterRegisteredToolName.applicationListRunning.rawValue
        case .click: return DexterRegisteredToolName.mouseClick.rawValue
        case .typeText: return DexterRegisteredToolName.keyboardType.rawValue
        case .keyPress: return DexterRegisteredToolName.keyboardPress.rawValue
        case .screenSnapshot, .screenObservation: return DexterRegisteredToolName.screenObserve.rawValue
        case .systemRun: return DexterRegisteredToolName.terminalRun.rawValue
        case .fileOperation: return registeredFileToolName(for: actionRequest)
        case .terminalOperation: return registeredTerminalToolName(for: actionRequest)
        case .scroll: return nil
        case .browserInteraction: return nil
        }
    }

    private static func registeredFileToolName(for actionRequest: AgentActionRequest) -> String? {
        switch actionRequest.parameters["fileAction"] ?? "" {
        case "search": return DexterRegisteredToolName.fileSearch.rawValue
        case "read": return DexterRegisteredToolName.fileRead.rawValue
        case "create": return DexterRegisteredToolName.fileCreate.rawValue
        case "write": return DexterRegisteredToolName.fileWrite.rawValue
        case "move": return DexterRegisteredToolName.fileMove.rawValue
        case "rename": return DexterRegisteredToolName.fileRename.rawValue
        case "delete": return DexterRegisteredToolName.fileDelete.rawValue
        default: return nil
        }
    }

    private static func registeredTerminalToolName(for actionRequest: AgentActionRequest) -> String? {
        switch actionRequest.parameters["terminalAction"] ?? "" {
        case "inspect": return DexterRegisteredToolName.terminalInspect.rawValue
        case "run": return DexterRegisteredToolName.terminalRun.rawValue
        case "captureOutput": return DexterRegisteredToolName.terminalCaptureOutput.rawValue
        default: return nil
        }
    }

    private static func registeredBrowserToolName(for actionRequest: AgentActionRequest) -> String? {
        switch actionRequest.parameters["browserAction"] ?? "" {
        case "open": return DexterRegisteredToolName.browserOpen.rawValue
        case "navigate": return DexterRegisteredToolName.browserNavigate.rawValue
        case "search": return DexterRegisteredToolName.browserSearch.rawValue
        case "read": return DexterRegisteredToolName.browserRead.rawValue
        case "click": return DexterRegisteredToolName.browserClick.rawValue
        case "type": return DexterRegisteredToolName.browserType.rawValue
        case "back": return DexterRegisteredToolName.browserBack.rawValue
        case "forward": return DexterRegisteredToolName.browserForward.rawValue
        default:
            if actionRequest.actionIdentifier == DexterActionType.openURL.rawValue {
                return DexterRegisteredToolName.browserOpen.rawValue
            }
            if actionRequest.parameters["query"] != nil {
                return DexterRegisteredToolName.browserSearch.rawValue
            }
            if actionRequest.parameters["url"] != nil || actionRequest.parameters["destination"] != nil {
                return DexterRegisteredToolName.browserNavigate.rawValue
            }
            return DexterRegisteredToolName.browserOpen.rawValue
        }
    }

    private static func nonEmptyApplicationName(from actionRequest: AgentActionRequest) -> String? {
        let applicationName = actionRequest.parameters["applicationName"] ?? ""
        let trimmed = applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
