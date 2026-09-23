//
//  DexterClipboardContextEvaluator.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterClipboardContextEvaluator {
    static func shouldIncludeClipboard(forUserMessage userMessage: String) -> Bool {
        let normalizedMessage = userMessage.lowercased()
        let clipboardKeywords = ["clipboard", "paste", "pasted", "copied", "copy and paste"]
        return clipboardKeywords.contains { normalizedMessage.contains($0) }
    }

    static func readClipboardStringForContext(maxCharacterCount: Int = 500) -> String? {
        let pasteboard = NSPasteboard.general
        guard let rawString = pasteboard.string(forType: .string) else {
            return nil
        }

        let trimmedString = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else {
            return nil
        }

        if trimmedString.count <= maxCharacterCount {
            return trimmedString
        }

        return String(trimmedString.prefix(maxCharacterCount))
    }
}
