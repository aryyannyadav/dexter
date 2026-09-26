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

/// Launch/focus/quit intent plus an optional in-app UI destination from the same utterance.
struct DexterApplicationLifecyclePlan: Equatable {
    let intent: DexterApplicationLifecycleIntent
    /// When the user says “open Saved Messages in Telegram”, this is “Saved Messages”.
    let inApplicationDestinationLabel: String?
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

    private static let listRunningApplicationPhrases = [
        "list running applications",
        "list running apps",
        "what applications are running",
        "what apps are running",
        "show running applications",
        "show running apps"
    ]

    static func matchesListRunningApplicationsIntent(normalizedUserMessage: String) -> Bool {
        let normalizedMessage = normalizedUserMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return listRunningApplicationPhrases.contains(normalizedMessage)
    }

    /// Isolates the application entity from text after a launch/focus/quit verb (stops at conjunctions and follow-on intents).
    static func extractApplicationEntity(fromLaunchRemainder remainder: String) -> String? {
        parseApplicationLaunchClause(fromLaunchRemainder: remainder)?.applicationName
    }

    static func parseApplicationLaunchClause(
        fromLaunchRemainder remainder: String
    ) -> (applicationName: String, inApplicationDestinationLabel: String?)? {
        var applicationFragment = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !applicationFragment.isEmpty else { return nil }

        if applicationFragment.hasSuffix(" settings") || applicationFragment.hasSuffix(" preferences") {
            let settingsSuffix = applicationFragment.hasSuffix(" settings") ? " settings" : " preferences"
            let applicationCandidate = String(applicationFragment.dropLast(settingsSuffix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let destinationLabel = settingsSuffix.contains("settings") ? "Settings" : "Preferences"
            if let resolvedApplicationName = DexterApplicationNameFormatter.canonicalApplicationName(from: applicationCandidate) {
                return (resolvedApplicationName, destinationLabel)
            }
        }

        if let inRange = applicationFragment.range(of: " in ", options: .backwards) {
            let applicationCandidate = String(applicationFragment[inRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let destinationCandidate = String(applicationFragment[..<inRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let resolvedApplicationName = DexterApplicationNameFormatter.canonicalApplicationName(from: applicationCandidate),
               let destinationLabel = DexterUserInterfaceDestinationLabelFormatter.canonicalLabel(
                   from: destinationCandidate
               ) {
                return (resolvedApplicationName, destinationLabel)
            }
        }

        let clauseBoundaries = [" and ", " then ", " after that ", ",", ";"]
        for boundary in clauseBoundaries {
            if let range = applicationFragment.range(of: boundary) {
                applicationFragment = String(applicationFragment[..<range.lowerBound])
            }
        }

        for trailingPhrase in [" there", " please", " for me"] {
            if applicationFragment.hasSuffix(trailingPhrase) {
                applicationFragment = String(applicationFragment.dropLast(trailingPhrase.count))
            }
        }

        applicationFragment = applicationFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !applicationFragment.isEmpty else { return nil }

        guard let applicationName = DexterApplicationNameFormatter.canonicalApplicationName(from: applicationFragment) else {
            return nil
        }
        return (applicationName, nil)
    }

    static func parse(from normalizedUserMessage: String) -> DexterApplicationLifecycleIntent? {
        parsePlan(from: normalizedUserMessage)?.intent
    }

    static func parsePlan(from normalizedUserMessage: String) -> DexterApplicationLifecyclePlan? {
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
            return DexterApplicationLifecyclePlan(intent: intent, inApplicationDestinationLabel: nil)
        }

        if let intent = parseWithPrefixes(
            normalizedMessage: normalizedMessage,
            prefixes: focusPrefixes,
            operation: .focus
        ) {
            return DexterApplicationLifecyclePlan(intent: intent, inApplicationDestinationLabel: nil)
        }

        if let plan = parseLaunchPlanWithPrefixes(
            normalizedMessage: normalizedMessage,
            prefixes: launchPrefixes,
            operation: .launch
        ) {
            return plan
        }

        return nil
    }

    private static func parseLaunchPlanWithPrefixes(
        normalizedMessage: String,
        prefixes: [String],
        operation: DexterApplicationLifecycleOperation
    ) -> DexterApplicationLifecyclePlan? {
        for commandPrefix in prefixes.sorted(by: { $0.count > $1.count }) {
            guard normalizedMessage.hasPrefix(commandPrefix) else { continue }

            var remainder = String(normalizedMessage.dropFirst(commandPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !remainder.isEmpty else { return nil }

            guard let launchClause = parseApplicationLaunchClause(fromLaunchRemainder: remainder) else {
                return nil
            }

            let resolvedReference = DexterApplicationReferenceResolver.resolve(userInput: launchClause.applicationName)
            let intent = DexterApplicationLifecycleIntent(
                operation: operation,
                applicationName: resolvedReference.displayName
            )
            return DexterApplicationLifecyclePlan(
                intent: intent,
                inApplicationDestinationLabel: launchClause.inApplicationDestinationLabel
            )
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

            guard let applicationName = DexterApplicationLifecycleIntentParser.extractApplicationEntity(
                fromLaunchRemainder: remainder
            ) else {
                return nil
            }

            let resolvedReference = DexterApplicationReferenceResolver.resolve(userInput: applicationName)
            return DexterApplicationLifecycleIntent(
                operation: operation,
                applicationName: resolvedReference.displayName
            )
        }

        return nil
    }
}

enum DexterUserInterfaceDestinationLabelFormatter {
    static func canonicalLabel(from rawFragment: String) -> String? {
        var destinationFragment = rawFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destinationFragment.isEmpty else { return nil }

        let destinationPrefixes = [
            "please open the ",
            "please open ",
            "open the ",
            "open ",
            "go to the ",
            "go to ",
            "navigate to the ",
            "navigate to ",
            "switch to the ",
            "switch to "
        ]
        for prefix in destinationPrefixes.sorted(by: { $0.count > $1.count }) {
            if destinationFragment.hasPrefix(prefix) {
                destinationFragment = String(destinationFragment.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        for trailingPhrase in [" section", " tab", " there", " please", " for me"] {
            if destinationFragment.hasSuffix(trailingPhrase) {
                destinationFragment = String(destinationFragment.dropLast(trailingPhrase.count))
            }
        }

        destinationFragment = destinationFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destinationFragment.isEmpty else { return nil }

        return destinationFragment
            .split(separator: " ")
            .map { word in
                let lowercasedWord = word.lowercased()
                return lowercasedWord.prefix(1).uppercased() + lowercasedWord.dropFirst()
            }
            .joined(separator: " ")
    }
}

enum DexterApplicationNameFormatter {
    static func canonicalApplicationName(from rawToken: String) -> String? {
        let trimmedToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return nil }

        let resolvedReference = DexterApplicationReferenceResolver.resolve(userInput: trimmedToken)
        return resolvedReference.displayName
    }
}
