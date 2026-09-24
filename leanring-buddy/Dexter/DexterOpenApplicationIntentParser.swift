//
//  DexterOpenApplicationIntentParser.swift
//

import Foundation

/// Backward-compatible entry point for launch-only parsing.
enum DexterOpenApplicationIntentParser {
    static func applicationName(from normalizedUserMessage: String) -> String? {
        guard let lifecycleIntent = DexterApplicationLifecycleIntentParser.parse(from: normalizedUserMessage),
              lifecycleIntent.operation == .launch else {
            return nil
        }
        return lifecycleIntent.applicationName
    }
}
