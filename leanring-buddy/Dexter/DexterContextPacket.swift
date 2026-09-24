//
//  DexterContextPacket.swift
//  leanring-buddy
//
//  First-class context output for a single Dexter invocation.
//

import CoreGraphics
import Foundation

/// How far out from the user's immediate focus context must reach for this request.
enum DexterContextRelevanceLevel: String, Equatable, CaseIterable {
    case object = "OBJECT"
    case region = "REGION"
    case window = "WINDOW"
    case application = "APPLICATION"
    case workflow = "WORKFLOW"
    case project = "PROJECT"
    case user = "USER"
    case longTerm = "LONG_TERM"
}

enum DexterContextPriority: String, Equatable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
}

struct DexterUserIntentContext: Equatable {
    let userMessage: String
    let minimumRelevanceLevel: DexterContextRelevanceLevel
}

struct DexterPointerTargetContext: Equatable {
    let semanticTarget: DexterPointerSemanticTarget
    let accessibilityHintAtPointer: DexterAccessibilityHintAtPointer
    let attentionRegionInScreenSpace: CGRect?
}

struct DexterContextPermissionSnapshot: Equatable {
    let hasScreenRecordingPermission: Bool
    let hasAccessibilityPermission: Bool
    let hasScreenContentPermission: Bool
    let hasMicrophonePermission: Bool
}

struct DexterAvailableToolDescriptor: Equatable {
    let toolKindIdentifier: String
    let openClawCapability: String?
    let isAvailable: Bool
}

struct DexterAvailableToolsContext: Equatable {
    let tools: [DexterAvailableToolDescriptor]
    let availability: DexterContextAvailability
}

struct DexterProjectContext: Equatable {
    let workflowLabel: String?
    let projectNotes: [String]
    let personalContextGraph: DexterPersonalContextGraphSnapshot?
    let crossApplicationContext: DexterCrossApplicationContext?
    let availability: DexterContextAvailability
}

struct DexterBrowserContext: Equatable {
    let frontmostApplicationName: String?
    let inferredPageURL: String?
    let inferredPageTitle: String?
    let pageIdentity: String?
    let relevantTextSnippet: String?
    let selectedElementDescription: String?
    let availability: DexterContextAvailability
}

/// Situational context collected for one invocation (not every field is populated every time).
struct DexterContextPacket: Equatable {
    let userIntent: DexterUserIntentContext
    let activeApplication: DexterActiveApplicationContext?
    let activeWindow: DexterActiveWindowContext?
    let display: DexterDisplayContext?
    let pointer: DexterPointerContext?
    let pointerTarget: DexterPointerTargetContext?
    let screenContext: DexterScreenContext?
    let selectedText: DexterSelectedTextContext?
    let clipboard: DexterClipboardContext?
    let memory: DexterPersistentMemoryContext?
    let conversation: DexterConversationContext?
    let currentTask: DexterTaskContext?
    let recentActions: DexterActionHistoryContext?
    let availableTools: DexterAvailableToolsContext?
    let permissions: DexterContextPermissionSnapshot?
    let projectContext: DexterProjectContext?
    let browserContext: DexterBrowserContext?
    let attention: DexterAttentionContext?
}

struct DexterContextSkippedSection: Equatable {
    let sectionName: String
    let reason: String
}

struct DexterContextCollectedSection: Equatable {
    let sectionName: String
    let relevanceLevel: DexterContextRelevanceLevel
    let priority: DexterContextPriority
    let detail: String
}

struct DexterContextAssemblyDiagnostics: Equatable {
    let collectedSections: [DexterContextCollectedSection]
    let skippedSections: [DexterContextSkippedSection]
}

struct DexterContextAssemblyResult: Equatable {
    let packet: DexterContextPacket
    let legacyContext: DexterContext
    let diagnostics: DexterContextAssemblyDiagnostics
}
