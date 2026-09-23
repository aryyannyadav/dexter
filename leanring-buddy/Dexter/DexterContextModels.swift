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
    let locationInScreenSpace: CGPoint
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

    init(currentTaskDescription: String?, activeWorkflowTask: DexterTask? = nil) {
        self.currentTaskDescription = currentTaskDescription
        self.activeWorkflowTask = activeWorkflowTask
    }
}

struct DexterPersistentMemoryContext: Equatable {
    let userPreferences: [DexterMemoryEntry]
    let rememberedFacts: [DexterMemoryEntry]
    let workflowContext: DexterWorkflowContextState?

    static let empty = DexterPersistentMemoryContext(
        userPreferences: [],
        rememberedFacts: [],
        workflowContext: nil
    )

    var hasAnyPersistentMemory: Bool {
        !userPreferences.isEmpty || !rememberedFacts.isEmpty || workflowContext != nil
    }
}
