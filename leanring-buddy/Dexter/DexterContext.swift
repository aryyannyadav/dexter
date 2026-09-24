//
//  DexterContext.swift
//  leanring-buddy
//
//  Snapshot of situational data Dexter can use for reasoning and actions.
//

import AppKit
import Foundation

/// A single labeled screen capture included in context (in-memory only for the invocation).
struct DexterScreenCaptureSnapshot: Equatable {
    let imageData: Data
    let label: String
    let isCursorScreen: Bool
    let displayWidthInPoints: Int
    let displayHeightInPoints: Int
    let displayFrame: CGRect
    let screenshotWidthInPixels: Int
    let screenshotHeightInPixels: Int
}

extension DexterScreenCaptureSnapshot {
    init(companionScreenCapture: CompanionScreenCapture) {
        imageData = companionScreenCapture.imageData
        label = companionScreenCapture.label
        isCursorScreen = companionScreenCapture.isCursorScreen
        displayWidthInPoints = companionScreenCapture.displayWidthInPoints
        displayHeightInPoints = companionScreenCapture.displayHeightInPoints
        displayFrame = companionScreenCapture.displayFrame
        screenshotWidthInPixels = companionScreenCapture.screenshotWidthInPixels
        screenshotHeightInPixels = companionScreenCapture.screenshotHeightInPixels
    }
}

extension CompanionScreenCapture {
    init(snapshot: DexterScreenCaptureSnapshot) {
        self.init(
            imageData: snapshot.imageData,
            label: snapshot.label,
            isCursorScreen: snapshot.isCursorScreen,
            displayWidthInPoints: snapshot.displayWidthInPoints,
            displayHeightInPoints: snapshot.displayHeightInPoints,
            displayFrame: snapshot.displayFrame,
            screenshotWidthInPixels: snapshot.screenshotWidthInPixels,
            screenshotHeightInPixels: snapshot.screenshotHeightInPixels
        )
    }
}

/// Fully typed context assembled once per Dexter invocation.
struct DexterContext: Equatable {
    var userMessage: DexterUserMessageContext
    var pointer: DexterPointerContext?
    var display: DexterDisplayContext?
    var screen: DexterScreenContext
    var activeApplication: DexterActiveApplicationContext
    var activeWindow: DexterActiveWindowContext
    var selectedText: DexterSelectedTextContext
    var clipboard: DexterClipboardContext
    var conversation: DexterConversationContext
    var recentActions: DexterActionHistoryContext
    var currentTask: DexterTaskContext
    var persistentMemory: DexterPersistentMemoryContext
    var personalContextGraph: DexterPersonalContextGraphSnapshot?
    var crossApplicationContext: DexterCrossApplicationContext?
    var attention: DexterAttentionContext

    init(
        userMessage: DexterUserMessageContext,
        pointer: DexterPointerContext? = nil,
        display: DexterDisplayContext? = nil,
        screen: DexterScreenContext = DexterScreenContext(
            primaryScreenshot: nil,
            allScreens: [],
            captureAvailability: .notApplicable
        ),
        activeApplication: DexterActiveApplicationContext = DexterActiveApplicationContext(
            bundleIdentifier: nil,
            localizedName: nil,
            availability: .notApplicable
        ),
        activeWindow: DexterActiveWindowContext = DexterActiveWindowContext(
            title: nil,
            availability: .notApplicable
        ),
        selectedText: DexterSelectedTextContext = DexterSelectedTextContext(
            selectedText: nil,
            availability: .notApplicable
        ),
        clipboard: DexterClipboardContext = DexterClipboardContext(
            stringValue: nil,
            inclusionReason: nil,
            availability: .notApplicable
        ),
        conversation: DexterConversationContext = DexterConversationContext(recentExchanges: []),
        recentActions: DexterActionHistoryContext = DexterActionHistoryContext(recentActions: []),
        currentTask: DexterTaskContext = DexterTaskContext(currentTaskDescription: nil),
        persistentMemory: DexterPersistentMemoryContext = .empty,
        personalContextGraph: DexterPersonalContextGraphSnapshot? = nil,
        crossApplicationContext: DexterCrossApplicationContext? = nil,
        attention: DexterAttentionContext? = nil
    ) {
        self.userMessage = userMessage
        let resolvedPointerLocation = pointer?.locationInScreenSpace ?? attention?.pointerLocationInScreenSpace ?? .zero
        self.pointer = pointer ?? DexterPointerContext(locationInScreenSpace: resolvedPointerLocation)
        self.display = display
        self.screen = screen
        self.activeApplication = activeApplication
        self.activeWindow = activeWindow
        self.selectedText = selectedText
        self.clipboard = clipboard
        self.conversation = conversation
        self.recentActions = recentActions
        self.currentTask = currentTask
        self.persistentMemory = persistentMemory
        self.personalContextGraph = personalContextGraph
        self.crossApplicationContext = crossApplicationContext
        self.attention = attention ?? DexterAttentionContext(
            pointerLocationInScreenSpace: resolvedPointerLocation,
            pointerLocationRelativeToDisplay: nil,
            regionAroundPointerInScreenSpace: nil,
            pointerLocationInPrimaryScreenshotPixels: nil,
            regionAroundPointerInPrimaryScreenshotPixels: nil,
            accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            ),
            primaryDisplayIdentifier: display?.displayIdentifier
        )
    }

    /// All screen captures from this invocation (empty when capture was skipped or denied).
    var screenCaptures: [DexterScreenCaptureSnapshot] {
        screen.allScreens
    }

    var pointerLocationInScreenSpace: CGPoint? {
        pointer?.locationInScreenSpace
    }

    var userTranscript: String? {
        userMessage.text
    }
}
