//
//  DexterContextModels.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Whether a context slice could be collected.
enum DexterContextAvailability: Equatable {
    case available
    case permissionMissing
    case notApplicable
    case unavailable(errorDescription: String)
}

struct DexterUserMessageContext: Equatable {
    let text: String
}

struct DexterPointerContext: Equatable {
    let screenDisplayIdentifier: UInt32?
    let locationInScreenSpace: CGPoint
    let capturedAt: Date
    let activeApplication: DexterActiveApplicationContext?
    let activeWindow: DexterActiveWindowContext?
    let semanticTarget: DexterPointerSemanticTarget?
    let confidence: Double
    let attentionRegionInScreenSpace: CGRect?

    var x: CGFloat { locationInScreenSpace.x }
    var y: CGFloat { locationInScreenSpace.y }

    init(
        screenDisplayIdentifier: UInt32? = nil,
        locationInScreenSpace: CGPoint,
        capturedAt: Date = Date(),
        activeApplication: DexterActiveApplicationContext? = nil,
        activeWindow: DexterActiveWindowContext? = nil,
        semanticTarget: DexterPointerSemanticTarget? = nil,
        confidence: Double = 0,
        attentionRegionInScreenSpace: CGRect? = nil
    ) {
        self.screenDisplayIdentifier = screenDisplayIdentifier
        self.locationInScreenSpace = locationInScreenSpace
        self.capturedAt = capturedAt
        self.activeApplication = activeApplication
        self.activeWindow = activeWindow
        self.semanticTarget = semanticTarget
        self.confidence = confidence
        self.attentionRegionInScreenSpace = attentionRegionInScreenSpace
    }
}

struct DexterDisplayContext: Equatable {
    let displayIdentifier: UInt32
    let displayFrameInScreenSpace: CGRect
}

struct DexterActiveApplicationContext: Equatable {
    let bundleIdentifier: String?
    let localizedName: String?
    let availability: DexterContextAvailability
}

struct DexterActiveWindowContext: Equatable {
    let title: String?
    let availability: DexterContextAvailability
}

struct DexterSelectedTextContext: Equatable {
    let selectedText: String?
    let availability: DexterContextAvailability
}

enum DexterClipboardInclusionReason: Equatable {
    case userMessageMentionedClipboard
}

struct DexterClipboardContext: Equatable {
    let stringValue: String?
    let inclusionReason: DexterClipboardInclusionReason?
    let availability: DexterContextAvailability
}

struct DexterScreenContext: Equatable {
    /// Cursor-screen capture when available; not persisted to disk.
    let primaryScreenshot: DexterScreenCaptureSnapshot?
    let allScreens: [DexterScreenCaptureSnapshot]
    let captureAvailability: DexterContextAvailability
}

struct DexterConversationContext: Equatable {
    let recentExchanges: [DexterConversationExchange]
    let earlierSessionSummary: String?
    let apiHistoryExchanges: [DexterConversationExchange]

    init(
        recentExchanges: [DexterConversationExchange],
        earlierSessionSummary: String? = nil,
        apiHistoryExchanges: [DexterConversationExchange]? = nil
    ) {
        self.recentExchanges = recentExchanges
        self.earlierSessionSummary = earlierSessionSummary
        self.apiHistoryExchanges = apiHistoryExchanges ?? recentExchanges
    }
}

struct DexterRecordedAction: Equatable {
    let actionIdentifier: String
    let summary: String
    let recordedAt: Date
}

struct DexterActionHistoryContext: Equatable {
    let recentActions: [DexterRecordedAction]
}

struct DexterTaskContext: Equatable {
    let currentTaskDescription: String?
    let activeWorkflowTask: DexterTask?
    let accountabilitySnapshot: DexterAccountabilityTaskSnapshot

    init(
        currentTaskDescription: String?,
        activeWorkflowTask: DexterTask? = nil,
        accountabilitySnapshot: DexterAccountabilityTaskSnapshot = .empty
    ) {
        self.currentTaskDescription = currentTaskDescription
        self.activeWorkflowTask = activeWorkflowTask
        self.accountabilitySnapshot = accountabilitySnapshot
    }
}

struct DexterPersistentMemoryContext: Equatable {
    let retrievedMemories: [DexterStructuredMemoryRecord]
    let workflowContext: DexterWorkflowContextState?

    var userPreferences: [DexterMemoryEntry] {
        retrievedMemories.filter { $0.type == .preference }.map { $0.legacyMemoryEntry() }
    }

    var rememberedFacts: [DexterMemoryEntry] {
        retrievedMemories
            .filter { $0.type == .semantic || $0.type == .episodic || $0.type == .commitment }
            .map { $0.legacyMemoryEntry() }
    }

    static let empty = DexterPersistentMemoryContext(
        retrievedMemories: [],
        workflowContext: nil
    )

    var hasAnyPersistentMemory: Bool {
        !retrievedMemories.isEmpty || workflowContext != nil
    }
}
