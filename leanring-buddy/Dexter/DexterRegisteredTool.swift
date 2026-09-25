//
//  DexterRegisteredTool.swift
//  leanring-buddy
//

import Foundation

enum DexterRegisteredToolName: String, Equatable, CaseIterable {
    case screenCapture = "screen.capture"
    case screenObserve = "screen.observe"
    case applicationLaunch = "application.launch"
    case applicationQuit = "application.quit"
    case applicationFocus = "application.focus"
    case applicationListRunning = "application.list_running"
    case mouseClick = "mouse.click"
    case keyboardType = "keyboard.type"
    case keyboardPress = "keyboard.press"
    case browserOpen = "browser.open"
    case browserNavigate = "browser.navigate"
    case browserSearch = "browser.search"
    case browserRead = "browser.read"
    case browserClick = "browser.click"
    case browserType = "browser.type"
    case browserBack = "browser.back"
    case browserForward = "browser.forward"
    case fileSearch = "file.search"
    case fileRead = "file.read"
    case fileCreate = "file.create"
    case fileWrite = "file.write"
    case fileMove = "file.move"
    case fileRename = "file.rename"
    case fileDelete = "file.delete"
    case terminalInspect = "terminal.inspect"
    case terminalRun = "terminal.run"
    case terminalCaptureOutput = "terminal.captureOutput"
}

enum DexterRegisteredToolRuntime: String, Equatable {
    case openClaw = "openclaw"
    case localMac = "local_mac"
    case unavailable = "unavailable"
}

enum DexterRegisteredToolVerificationStrategy: String, Equatable {
    case screenCaptureOnly = "screen_capture_only"
    case applicationLifecycle = "application_lifecycle"
    case pointerUIChange = "pointer_ui_change"
    case browserState = "browser_state"
    case textEntry = "text_entry"
    case commandOutput = "command_output"
    case filesystemState = "filesystem_state"
    case unavailable = "unavailable"
}

struct DexterRegisteredToolDefinition: Equatable, Identifiable {
    let name: DexterRegisteredToolName
    let description: String
    let inputSchemaJSON: String
    let riskLevel: DexterActionRiskLevel
    let requiredPermissions: [String]
    let runtime: DexterRegisteredToolRuntime
    let verificationStrategy: DexterRegisteredToolVerificationStrategy
    let supportsCancellation: Bool
    let requiredOpenClawCapability: DexterOpenClawCapabilityKind?

    var id: String { name.rawValue }
}

struct DexterRegisteredToolProposal: Equatable {
    let toolName: String
    let parameters: [String: String]
}

enum DexterToolRegistryValidationError: Error, Equatable {
    case unknownTool(String)
    case toolNotAvailable(String)
    case invalidParameters(String)
}

struct DexterRegisteredToolMetadata: Equatable {
    let name: String
    let description: String
    let inputSchemaJSON: String
    let riskLevel: String
    let requiredPermissions: [String]
    let runtime: String
    let verificationStrategy: String
    let supportsCancellation: Bool
}
