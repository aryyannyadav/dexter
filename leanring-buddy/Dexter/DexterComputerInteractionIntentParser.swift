//
//  DexterComputerInteractionIntentParser.swift
//  leanring-buddy
//

import Foundation

enum DexterComputerInteractionIntent: Equatable {
    case scroll(direction: String, amount: String?)
    case typeText(String)
    case keyboardShortcut(String)
    case clickPointer(button: String)
}

enum DexterComputerInteractionIntentParser {
    static func parse(from normalizedUserMessage: String) -> DexterComputerInteractionIntent? {
        if let scrollIntent = parseScrollIntent(from: normalizedUserMessage) {
            return scrollIntent
        }
        if let typeIntent = parseTypeIntent(from: normalizedUserMessage) {
            return typeIntent
        }
        if let keyboardIntent = parseKeyboardIntent(from: normalizedUserMessage) {
            return keyboardIntent
        }
        if let clickIntent = parsePointerClickIntent(from: normalizedUserMessage) {
            return clickIntent
        }
        return nil
    }

    private static func parseScrollIntent(from normalizedUserMessage: String) -> DexterComputerInteractionIntent? {
        guard normalizedUserMessage.contains("scroll") else { return nil }
        if normalizedUserMessage.contains("scroll down") || normalizedUserMessage == "scroll" {
            return .scroll(direction: "down", amount: nil)
        }
        if normalizedUserMessage.contains("scroll up") {
            return .scroll(direction: "up", amount: nil)
        }
        if normalizedUserMessage.contains("scroll left") {
            return .scroll(direction: "left", amount: nil)
        }
        if normalizedUserMessage.contains("scroll right") {
            return .scroll(direction: "right", amount: nil)
        }
        return nil
    }

    private static func parseTypeIntent(from normalizedUserMessage: String) -> DexterComputerInteractionIntent? {
        let prefixes = ["type ", "type in ", "enter "]
        for prefix in prefixes {
            guard normalizedUserMessage.hasPrefix(prefix) else { continue }
            let typedText = String(normalizedUserMessage.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !typedText.isEmpty else { return nil }
            return .typeText(typedText)
        }
        return nil
    }

    private static func parseKeyboardIntent(from normalizedUserMessage: String) -> DexterComputerInteractionIntent? {
        let prefixes = ["press ", "hit ", "keyboard shortcut "]
        for prefix in prefixes {
            guard normalizedUserMessage.hasPrefix(prefix) else { continue }
            let shortcutDescription = String(normalizedUserMessage.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !shortcutDescription.isEmpty else { return nil }
            return .keyboardShortcut(shortcutDescription)
        }
        return nil
    }

    private static func parsePointerClickIntent(from normalizedUserMessage: String) -> DexterComputerInteractionIntent? {
        let rightClickPhrases = ["right click it", "right click this", "right-click it", "right-click this"]
        if rightClickPhrases.contains(normalizedUserMessage) {
            return .clickPointer(button: "right")
        }
        let doubleClickPhrases = ["double click it", "double click this", "double-click it", "double-click this"]
        if doubleClickPhrases.contains(normalizedUserMessage) {
            return .clickPointer(button: "double")
        }
        return nil
    }
}
