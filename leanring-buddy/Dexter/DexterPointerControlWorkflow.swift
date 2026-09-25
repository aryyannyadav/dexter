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

    static func matchesPointerTeachIntent(normalizedUserMessage: String) -> Bool {
        let teachPhrases = [
            "how do i use",
            "how to use",
            "how do i click",
            "how do i enable",
            "show me how",
            "walk me through",
            "teach me how",
            "teach me this",
            "teach me that"
        ]
        return teachPhrases.contains { normalizedUserMessage.contains($0) }
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
        let pointerLocation = context.attention.pointerLocationInScreenSpace
        guard pointerLocation.x.isFinite, pointerLocation.y.isFinite else {
            return nil
        }
        return pointerLocation
    }

    static func controlLabelForConfirmation(from context: DexterContext) -> String {
        if let semanticTarget = context.pointer?.semanticTarget {
            return semanticTarget.confirmationLabel
        }
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
