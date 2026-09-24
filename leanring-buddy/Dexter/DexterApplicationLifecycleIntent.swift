//
//  DexterApplicationLifecycleIntent.swift
//  leanring-buddy
//

import Foundation

enum DexterApplicationLifecycleOperation: String, Equatable {
    case launch = "launch"
    case focus = "focus"
    case quit = "quit"
}

struct DexterApplicationLifecycleIntent: Equatable {
    let operation: DexterApplicationLifecycleOperation
    let applicationName: String
}

/// Parses generic application lifecycle intents (open / focus / quit) without per-app hardcoding.
enum DexterApplicationLifecycleIntentParser {
    private static let launchPrefixes = [
        "please open ",
        "please launch ",
        "please start ",
        "open the ",
        "launch the ",
        "start the ",
        "open ",
        "launch ",
        "start "
    ]

    private static let focusPrefixes = [
        "please focus ",
        "please switch to ",
        "switch to ",
        "focus ",
        "bring ",
        "activate "
    ]

    private static let quitPrefixes = [
        "please quit ",
        "please close ",
        "please exit ",
        "quit the ",
        "close the ",
        "exit the ",
        "quit ",
        "close ",
        "exit ",
        "kill "
    ]

    static func parse(from normalizedUserMessage: String) -> DexterApplicationLifecycleIntent? {
        let normalizedMessage = normalizedUserMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedMessage.isEmpty else { return nil }

        guard !normalizedMessage.contains(" and search"),
              !normalizedMessage.contains(" and find"),
              !normalizedMessage.contains(" and then") else {
            return nil
        }

        if let intent = parseWithPrefixes(
            normalizedMessage: normalizedMessage,
            prefixes: quitPrefixes,
            operation: .quit
        ) {
            return intent
        }

        if let intent = parseWithPrefixes(
            normalizedMessage: normalizedMessage,
            prefixes: focusPrefixes,
            operation: .focus
        ) {
            return intent
        }

        if let intent = parseWithPrefixes(
            normalizedMessage: normalizedMessage,
            prefixes: launchPrefixes,
            operation: .launch
        ) {
            return intent
        }

        return nil
    }

    private static func parseWithPrefixes(
        normalizedMessage: String,
        prefixes: [String],
        operation: DexterApplicationLifecycleOperation
    ) -> DexterApplicationLifecycleIntent? {
        for commandPrefix in prefixes.sorted(by: { $0.count > $1.count }) {
            guard normalizedMessage.hasPrefix(commandPrefix) else { continue }

            var remainder = String(normalizedMessage.dropFirst(commandPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !remainder.isEmpty else { return nil }

            if operation == .focus, remainder.hasPrefix("to the front") {
                remainder = remainder.replacingOccurrences(of: "to the front", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if operation == .focus, remainder.hasPrefix("to front") {
                remainder = remainder.replacingOccurrences(of: "to front", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if operation == .quit, remainder.hasPrefix("app ") {
                remainder = String(remainder.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let applicationToken = remainder
                .split(separator: " ")
                .prefix(4)
                .joined(separator: " ")

            guard let applicationName = DexterApplicationNameFormatter.canonicalApplicationName(from: applicationToken) else {
                return nil
            }

            return DexterApplicationLifecycleIntent(operation: operation, applicationName: applicationName)
        }

        return nil
    }
}

enum DexterApplicationNameFormatter {
    static func canonicalApplicationName(from rawToken: String) -> String? {
        let trimmedToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return nil }

        let lowercased = trimmedToken.lowercased()
        if let demoName = DexterDemoApplicationNames.canonicalName(for: lowercased) {
            return demoName
        }

        return trimmedToken
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
