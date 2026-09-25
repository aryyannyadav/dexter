//
//  DexterProductCapabilityRegistry.swift
//  leanring-buddy
//

import Foundation

struct DexterProductCapabilityBuildInput: Equatable {
    let discoveryReport: DexterOpenClawCapabilityDiscoveryReport
    let gatewayConnected: Bool
    let hasAccessibilityPermission: Bool
    let hasScreenRecordingPermission: Bool
    let hasMicrophonePermission: Bool
    let hasScreenContentPermission: Bool
    let integrations: [DexterIntegration]
}

enum DexterProductCapabilityRegistry {
    static func buildCapabilities(input: DexterProductCapabilityBuildInput) -> [DexterProductCapability] {
        let openClawComputer = input.discoveryReport.isCapabilityAvailable(.computerAct)
        let openClawScreen = input.discoveryReport.isCapabilityAvailable(.screenSnapshot)
        let openClawBrowser = input.discoveryReport.isCapabilityAvailable(.browserProxy)
        let openClawFiles = input.discoveryReport.isCapabilityAvailable(.file)
        let openClawTerminal = input.discoveryReport.isCapabilityAvailable(.systemRun)

        let localComputerLifecycle = input.hasAccessibilityPermission
        let computerControlAvailability: DexterProductCapabilityAvailability
        if openClawComputer {
            computerControlAvailability = .available
        } else if localComputerLifecycle {
            computerControlAvailability = .available
        } else if input.gatewayConnected && !openClawComputer {
            computerControlAvailability = .requiresPermission
        } else if !input.gatewayConnected {
            computerControlAvailability = .requiresConnection
        } else {
            computerControlAvailability = .unavailable
        }

        let launchAvailability: DexterProductCapabilityAvailability
        if openClawComputer || localComputerLifecycle {
            launchAvailability = .available
        } else if !input.gatewayConnected {
            launchAvailability = .requiresConnection
        } else {
            launchAvailability = .requiresPermission
        }

        let pointerAvailability: DexterProductCapabilityAvailability
        if openClawComputer && input.hasAccessibilityPermission {
            pointerAvailability = .available
        } else if openClawComputer {
            pointerAvailability = .requiresPermission
        } else if input.hasAccessibilityPermission {
            pointerAvailability = .available
        } else {
            pointerAvailability = .requiresPermission
        }

        let screenContextAvailability: DexterProductCapabilityAvailability
        if input.hasScreenRecordingPermission && input.hasScreenContentPermission {
            screenContextAvailability = .available
        } else if input.hasScreenRecordingPermission {
            screenContextAvailability = .requiresPermission
        } else {
            screenContextAvailability = .requiresPermission
        }

        let screenUnderstandingAvailability: DexterProductCapabilityAvailability
        if openClawScreen || (input.hasScreenRecordingPermission && input.hasScreenContentPermission) {
            screenUnderstandingAvailability = .available
        } else if input.hasScreenRecordingPermission {
            screenUnderstandingAvailability = .requiresPermission
        } else {
            screenUnderstandingAvailability = .requiresPermission
        }

        let browserIntegrationConnected = input.integrations.first(where: { $0.id == "browser" })?.connectionState == .connected
        let browserAvailability: DexterProductCapabilityAvailability
        if openClawBrowser || browserIntegrationConnected {
            browserAvailability = .available
        } else if input.gatewayConnected {
            browserAvailability = .unavailable
        } else {
            browserAvailability = .requiresConnection
        }

        let filesAvailability: DexterProductCapabilityAvailability
        if openClawFiles {
            filesAvailability = .available
        } else {
            filesAvailability = .available
        }

        let terminalAvailability: DexterProductCapabilityAvailability
        if openClawTerminal {
            terminalAvailability = .available
        } else {
            terminalAvailability = .available
        }

        let voiceRecognition: DexterProductCapabilityAvailability = input.hasMicrophonePermission
            ? .available
            : .requiresPermission

        return [
            capability(
                id: .computerControl,
                name: "Computer control",
                description: "Interact with supported applications on your Mac when permissions and runtime allow.",
                category: .computer,
                availability: computerControlAvailability,
                permission: computerControlAvailability == .requiresPermission
                    ? "Accessibility and Dexter's computer runtime"
                    : nil,
                provider: openClawComputer ? "OpenClaw + Mac" : "Mac",
                icon: "cursorarrow.click",
                skill: true
            ),
            capability(
                id: .computerLaunchApp,
                name: "Open applications",
                description: "Open, focus, or quit applications you name.",
                category: .computer,
                availability: launchAvailability,
                permission: launchAvailability == .requiresPermission ? "Accessibility" : nil,
                provider: "Mac workspace",
                icon: "app.badge",
                skill: false
            ),
            capability(
                id: .computerPointer,
                name: "Pointer actions",
                description: "Click, type, and scroll at the pointer when Dexter has context.",
                category: .computer,
                availability: pointerAvailability,
                permission: "Accessibility",
                provider: openClawComputer ? "OpenClaw" : "Mac",
                icon: "hand.point.up.left",
                skill: false
            ),
            capability(
                id: .screenContext,
                name: "Screen context",
                description: "Capture screen context for answers when you invoke Dexter.",
                category: .screen,
                availability: screenContextAvailability,
                permission: "Screen Recording",
                provider: "Dexter",
                icon: "rectangle.inset.filled.and.person.filled",
                skill: true
            ),
            capability(
                id: .screenUnderstanding,
                name: "Screen understanding",
                description: "Explain what's on screen using vision and context you already approved.",
                category: .screen,
                availability: screenUnderstandingAvailability,
                permission: "Screen Recording",
                provider: "Dexter",
                icon: "eye",
                skill: true
            ),
            capability(
                id: .browserNavigation,
                name: "Browser",
                description: "Read and navigate pages through Dexter's browser tools when available.",
                category: .browser,
                availability: browserAvailability,
                permission: nil,
                provider: openClawBrowser ? "OpenClaw browser proxy" : "Browser context",
                icon: "globe",
                skill: true
            ),
            capability(
                id: .filesLocal,
                name: "Files",
                description: "Search and organize files in approved folders.",
                category: .files,
                availability: filesAvailability,
                permission: nil,
                provider: openClawFiles ? "OpenClaw + local" : "Local",
                icon: "folder",
                skill: true
            ),
            capability(
                id: .terminalCommands,
                name: "Terminal",
                description: "Run approved terminal commands when policy allows.",
                category: .files,
                availability: terminalAvailability,
                permission: nil,
                provider: openClawTerminal ? "OpenClaw + local" : "Local policy",
                icon: "terminal",
                skill: true
            ),
            capability(
                id: .voiceRecognition,
                name: "Voice input",
                description: "Push-to-talk and speech recognition.",
                category: .voice,
                availability: voiceRecognition,
                permission: "Microphone",
                provider: "Dexter Voice",
                icon: "mic",
                skill: true
            ),
            capability(
                id: .voiceConversation,
                name: "Voice conversations",
                description: "Spoken responses when voice output is enabled.",
                category: .voice,
                availability: .available,
                permission: nil,
                provider: "Dexter Voice",
                icon: "waveform",
                skill: true
            ),
            capability(
                id: .memoryPersistent,
                name: "Memory",
                description: "Remember facts and recall them in future conversations.",
                category: .memory,
                availability: .available,
                permission: nil,
                provider: "Dexter",
                icon: "brain.head.profile",
                skill: true
            ),
            capability(
                id: .researchConversation,
                name: "Research",
                description: "Summarize and answer from context, memory, and connected tools.",
                category: .research,
                availability: .available,
                permission: nil,
                provider: "Dexter",
                icon: "text.book.closed",
                skill: true
            )
        ]
    }

    static func capability(
        for id: DexterProductCapabilityID,
        in capabilities: [DexterProductCapability]
    ) -> DexterProductCapability? {
        capabilities.first { $0.capabilityID == id }
    }

    static func isCapabilityUsable(
        _ id: DexterProductCapabilityID,
        in capabilities: [DexterProductCapability]
    ) -> Bool {
        guard let capability = capability(for: id, in: capabilities) else { return false }
        return capability.availability == .available
    }

    private static func capability(
        id: DexterProductCapabilityID,
        name: String,
        description: String,
        category: DexterProductCapabilityCategory,
        availability: DexterProductCapabilityAvailability,
        permission: String?,
        provider: String,
        icon: String,
        skill: Bool
    ) -> DexterProductCapability {
        DexterProductCapability(
            capabilityID: id,
            displayName: name,
            description: description,
            category: category,
            availability: availability,
            requiresPermissionSummary: permission,
            providerSummary: provider,
            systemImageName: icon,
            isSkillHighlight: skill
        )
    }
}
