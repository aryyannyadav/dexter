//
//  DexterPointerControlWorkflow.swift
//  leanring-buddy
//
//  One reliable non-coding workflow: POINT → ASK → UNDERSTAND → EXPLAIN → ACT → VERIFY
//  at the user's pointer (Safari, System Settings, or any AX-visible control).
//

import CoreGraphics
import Foundation

enum DexterPointerControlWorkflow {
    static let pointFirstMessage =
        "Point at the control on screen first, then ask what it is or say enable it."

    static func matchesPointerActIntent(normalizedUserMessage: String) -> Bool {
        let imperativePhrases: Set<String> = [
            "enable it",
            "enable this",
            "turn it on",
            "turn this on",
            "toggle it",
            "toggle this",
            "click it",
            "press it",
            "activate it",
            "select it"
        ]
        return imperativePhrases.contains(normalizedUserMessage)
    }

    static func matchesPointerExplainIntent(normalizedUserMessage: String) -> Bool {
        if DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedUserMessage) {
            return true
        }
        let hypotheticalPhrases = [
            "what happens if i enable",
            "what happens if i turn on",
            "what happens if i click",
            "what happens if i toggle",
            "what would happen if i enable",
            "what would happen if i turn on"
        ]
        return hypotheticalPhrases.contains { normalizedUserMessage.contains($0) }
    }

    static func validatedPointerLocationInScreenSpace(for context: DexterContext) -> CGPoint? {
        guard context.screen.captureAvailability == .available,
              !context.screen.allScreens.isEmpty else {
            return nil
        }
        let pointerLocation = context.attention.pointerLocationInScreenSpace
        guard pointerLocation.x.isFinite, pointerLocation.y.isFinite else {
            return nil
        }
        return pointerLocation
    }

    static func controlLabelForConfirmation(from context: DexterContext) -> String {
        let hint = context.attention.accessibilityHintAtPointer
        if let title = hint.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let roleDescription = hint.roleDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !roleDescription.isEmpty {
            return roleDescription
        }
        return "the control under your pointer"
    }
}
