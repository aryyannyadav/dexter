//
//  DexterProductCapabilityModels.swift
//  leanring-buddy
//
//  Product-level capability view (distinct from OpenClaw node command registry).
//

import Foundation

enum DexterProductCapabilityCategory: String, CaseIterable, Equatable {
    case computer
    case screen
    case browser
    case files
    case voice
    case memory
    case research
    case integrations

    var displayName: String {
        switch self {
        case .computer: return "Computer"
        case .screen: return "Screen"
        case .browser: return "Browser"
        case .files: return "Files"
        case .voice: return "Voice"
        case .memory: return "Memory"
        case .research: return "Research"
        case .integrations: return "Integrations"
        }
    }
}

enum DexterProductCapabilityAvailability: Equatable {
    case available
    case unavailable
    case requiresPermission
    case requiresConnection
    case unsupported

    var statusLabel: String {
        switch self {
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        case .requiresPermission: return "Needs permission"
        case .requiresConnection: return "Needs connection"
        case .unsupported: return "Unsupported"
        }
    }
}

enum DexterProductCapabilityID: String, CaseIterable, Equatable, Codable {
    case computerControl = "computer.control"
    case computerLaunchApp = "computer.launch_app"
    case computerPointer = "computer.pointer"
    case screenContext = "screen.context"
    case screenUnderstanding = "screen.understanding"
    case browserNavigation = "browser.navigation"
    case filesLocal = "files.local"
    case terminalCommands = "terminal.commands"
    case voiceRecognition = "voice.recognition"
    case voiceConversation = "voice.conversation"
    case memoryPersistent = "memory.persistent"
    case researchConversation = "research.conversation"
}

struct DexterProductCapability: Identifiable, Equatable {
    let capabilityID: DexterProductCapabilityID
    let displayName: String
    let description: String
    let category: DexterProductCapabilityCategory
    let availability: DexterProductCapabilityAvailability
    let requiresPermissionSummary: String?
    let providerSummary: String
    let systemImageName: String
    let isSkillHighlight: Bool

    var id: String { capabilityID.rawValue }
}

struct DexterActionRequirement: Equatable {
    let capabilityID: DexterProductCapabilityID
    let integrationID: String?
}

enum DexterActionCapabilityGateOutcome: Equatable {
    case allowed
    case blocked(userMessage: String)
}
