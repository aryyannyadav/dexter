//
//  DexterToolRegistryCatalog.swift
//  leanring-buddy
//

import Foundation

enum DexterToolRegistryCatalog {
    static let allDefinitions: [DexterRegisteredToolDefinition] = [
        DexterRegisteredToolDefinition(
            name: .screenCapture,
            description: "Capture the screen on demand for this request (not continuous recording).",
            inputSchemaJSON: #"{"type":"object","properties":{"scope":{"enum":["cursorDisplay","allDisplays"]}},"required":[]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["screenRecording"],
            runtime: .localMac,
            verificationStrategy: .screenCaptureOnly,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .screenObserve,
            description: "Observe the current screen through the connected OpenClaw node snapshot.",
            inputSchemaJSON: #"{"type":"object","properties":{},"required":[]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["screenRecording"],
            runtime: .openClaw,
            verificationStrategy: .screenCaptureOnly,
            supportsCancellation: true,
            requiredOpenClawCapability: .screenSnapshot
        ),
        DexterRegisteredToolDefinition(
            name: .applicationLaunch,
            description: "Launch an application by name.",
            inputSchemaJSON: #"{"type":"object","properties":{"applicationName":{"type":"string"}},"required":["applicationName"]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .applicationLifecycle,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .applicationQuit,
            description: "Quit an application by name.",
            inputSchemaJSON: #"{"type":"object","properties":{"applicationName":{"type":"string"}},"required":["applicationName"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .applicationLifecycle,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .applicationFocus,
            description: "Bring an application to the front.",
            inputSchemaJSON: #"{"type":"object","properties":{"applicationName":{"type":"string"}},"required":["applicationName"]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .applicationLifecycle,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .applicationListRunning,
            description: "List running applications through the connected OpenClaw computer-use provider.",
            inputSchemaJSON: #"{"type":"object","properties":{},"required":[]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .commandOutput,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .mouseClick,
            description: "Click at screen coordinates.",
            inputSchemaJSON: #"{"type":"object","properties":{"x":{"type":"string"},"y":{"type":"string"},"label":{"type":"string"}},"required":["x","y"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .pointerUIChange,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .keyboardType,
            description: "Type text through the computer control runtime.",
            inputSchemaJSON: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#,
            riskLevel: .moderateRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .textEntry,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .keyboardPress,
            description: "Press a keyboard shortcut.",
            inputSchemaJSON: #"{"type":"object","properties":{"keys":{"type":"string"}},"required":["keys"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .pointerUIChange,
            supportsCancellation: true,
            requiredOpenClawCapability: .computerAct
        ),
        DexterRegisteredToolDefinition(
            name: .browserOpen,
            description: "Open a URL in the browser runtime.",
            inputSchemaJSON: #"{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserNavigate,
            description: "Navigate the browser to a URL.",
            inputSchemaJSON: #"{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserSearch,
            description: "Run a browser search query.",
            inputSchemaJSON: #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserRead,
            description: "Read the current browser page content through OpenClaw.",
            inputSchemaJSON: #"{"type":"object","properties":{},"required":[]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserClick,
            description: "Click within the browser surface.",
            inputSchemaJSON: #"{"type":"object","properties":{"x":{"type":"string"},"y":{"type":"string"}},"required":["x","y"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserType,
            description: "Type into the focused browser field.",
            inputSchemaJSON: #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"#,
            riskLevel: .moderateRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserBack,
            description: "Navigate back in browser history.",
            inputSchemaJSON: #"{"type":"object","properties":{},"required":[]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .browserForward,
            description: "Navigate forward in browser history.",
            inputSchemaJSON: #"{"type":"object","properties":{},"required":[]}"#,
            riskLevel: .lowRisk,
            requiredPermissions: ["accessibility"],
            runtime: .openClaw,
            verificationStrategy: .browserState,
            supportsCancellation: true,
            requiredOpenClawCapability: .browserProxy
        ),
        DexterRegisteredToolDefinition(
            name: .fileSearch,
            description: "Search for files by name under an approved folder.",
            inputSchemaJSON: #"{"type":"object","properties":{"query":{"type":"string"},"searchRoot":{"type":"string"}},"required":["query"]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .fileRead,
            description: "Read a file from an approved path.",
            inputSchemaJSON: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .fileCreate,
            description: "Create a new file at an approved path.",
            inputSchemaJSON: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path"]}"#,
            riskLevel: .moderateRisk,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .fileWrite,
            description: "Write content to an approved file path.",
            inputSchemaJSON: #"{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .fileMove,
            description: "Move a file between approved paths.",
            inputSchemaJSON: #"{"type":"object","properties":{"path":{"type":"string"},"destinationPath":{"type":"string"}},"required":["path","destinationPath"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .fileRename,
            description: "Rename a file within an approved folder.",
            inputSchemaJSON: #"{"type":"object","properties":{"path":{"type":"string"},"newName":{"type":"string"}},"required":["path","newName"]}"#,
            riskLevel: .moderateRisk,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .fileDelete,
            description: "Delete a file at an approved path.",
            inputSchemaJSON: #"{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .filesystemState,
            supportsCancellation: false,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .terminalInspect,
            description: "Inspect the environment with an approved read-only command template (no raw shell).",
            inputSchemaJSON: #"{"type":"object","properties":{"commandTemplate":{"type":"string"},"pathArgument":{"type":"string"},"workingDirectory":{"type":"string"}},"required":["commandTemplate"]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .commandOutput,
            supportsCancellation: true,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .terminalRun,
            description: "Run an approved structured command template (not arbitrary shell).",
            inputSchemaJSON: #"{"type":"object","properties":{"commandTemplate":{"type":"string"},"pathArgument":{"type":"string"},"workingDirectory":{"type":"string"}},"required":["commandTemplate"]}"#,
            riskLevel: .highRisk,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .commandOutput,
            supportsCancellation: true,
            requiredOpenClawCapability: nil
        ),
        DexterRegisteredToolDefinition(
            name: .terminalCaptureOutput,
            description: "Capture sanitized terminal output from an approved command template.",
            inputSchemaJSON: #"{"type":"object","properties":{"commandTemplate":{"type":"string"},"expectedOutputContains":{"type":"string"},"pathArgument":{"type":"string"},"workingDirectory":{"type":"string"}},"required":["commandTemplate"]}"#,
            riskLevel: .readOnly,
            requiredPermissions: ["filesystem"],
            runtime: .localMac,
            verificationStrategy: .commandOutput,
            supportsCancellation: true,
            requiredOpenClawCapability: nil
        ),
    ]

    static func definition(for toolName: String) -> DexterRegisteredToolDefinition? {
        guard let registeredName = DexterRegisteredToolName(rawValue: toolName) else { return nil }
        return allDefinitions.first(where: { $0.name == registeredName })
    }
}
