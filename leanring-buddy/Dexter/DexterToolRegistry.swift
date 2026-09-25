//
//  DexterToolRegistry.swift
//  leanring-buddy
//

import Foundation

struct DexterToolRegistryAvailabilityContext: Equatable {
    let discoveryReport: DexterOpenClawCapabilityDiscoveryReport
    let hasScreenRecordingPermission: Bool
    let hasAccessibilityPermission: Bool
    let isOpenClawInstalled: Bool
}

enum DexterToolRegistry {
    static func allDefinitions() -> [DexterRegisteredToolDefinition] {
        DexterToolRegistryCatalog.allDefinitions
    }

    static func availableDefinitions(context: DexterToolRegistryAvailabilityContext) -> [DexterRegisteredToolDefinition] {
        allDefinitions().filter { isAvailable($0, context: context) }
    }

    static func metadataForModel(from definitions: [DexterRegisteredToolDefinition]) -> [DexterRegisteredToolMetadata] {
        definitions.map { definition in
            DexterRegisteredToolMetadata(
                name: definition.name.rawValue,
                description: definition.description,
                inputSchemaJSON: definition.inputSchemaJSON,
                riskLevel: definition.riskLevel.rawValue,
                requiredPermissions: definition.requiredPermissions,
                runtime: definition.runtime.rawValue,
                verificationStrategy: definition.verificationStrategy.rawValue,
                supportsCancellation: definition.supportsCancellation
            )
        }
    }

    static func modelPromptSection(from definitions: [DexterRegisteredToolDefinition]) -> String {
        let metadata = metadataForModel(from: definitions)
        guard !metadata.isEmpty else {
            return "AVAILABLE TOOLS: none on this machine/runtime."
        }

        let lines = metadata.map { entry in
            """
            - name: \(entry.name)
              description: \(entry.description)
              inputSchema: \(entry.inputSchemaJSON)
              riskLevel: \(entry.riskLevel)
              requiredPermissions: \(entry.requiredPermissions.joined(separator: ","))
              runtime: \(entry.runtime)
              verificationStrategy: \(entry.verificationStrategy)
              supportsCancellation: \(entry.supportsCancellation)
            """
        }
        return "AVAILABLE TOOLS (propose only these registered tools):\n" + lines.joined(separator: "\n")
    }

    static func isAvailable(
        _ definition: DexterRegisteredToolDefinition,
        context: DexterToolRegistryAvailabilityContext
    ) -> Bool {
        switch definition.runtime {
        case .unavailable:
            return false
        case .localMac:
            return localMacToolIsAvailable(definition, context: context)
        case .openClaw:
            return openClawToolIsAvailable(definition, context: context)
        }
    }

    private static func localMacToolIsAvailable(
        _ definition: DexterRegisteredToolDefinition,
        context: DexterToolRegistryAvailabilityContext
    ) -> Bool {
        switch definition.name {
        case .screenCapture:
            return context.hasScreenRecordingPermission
        case .fileSearch, .fileRead, .fileCreate, .fileWrite, .fileMove, .fileRename, .fileDelete:
            if context.discoveryReport.isCapabilityAvailable(.file) {
                return context.isOpenClawInstalled && context.discoveryReport.nodeConnected
            }
            return true
        case .terminalInspect, .terminalRun, .terminalCaptureOutput:
            return true
        default:
            return false
        }
    }

    private static func openClawToolIsAvailable(
        _ definition: DexterRegisteredToolDefinition,
        context: DexterToolRegistryAvailabilityContext
    ) -> Bool {
        guard context.isOpenClawInstalled else { return false }
        guard context.discoveryReport.nodeConnected else { return false }

        if definition.name == .screenObserve, !context.hasScreenRecordingPermission {
            return false
        }

        guard let capability = definition.requiredOpenClawCapability else { return false }
        guard context.discoveryReport.isCapabilityAvailable(capability) else { return false }

        let toolKind = openClawToolKind(for: definition.name)
        if let toolKind,
           DexterOpenClawApplicationLifecycleCapabilities.isApplicationLifecycleToolKind(toolKind) {
            return DexterOpenClawApplicationLifecycleCapabilities.supportsToolExecution(
                toolKind: toolKind,
                computerUseDescriptor: context.discoveryReport.computerUseDescriptor
            )
        }
        return true
    }

    private static func openClawToolKind(for toolName: DexterRegisteredToolName) -> DexterToolKind? {
        switch toolName {
        case .applicationLaunch: return .launchApplication
        case .applicationQuit: return .quitApplication
        case .applicationFocus: return .focusApplication
        case .applicationListRunning: return .listRunningApplications
        default: return nil
        }
    }
}
