//
//  DexterMemoryContentPolicy.swift
//  leanring-buddy
//

import Foundation

enum DexterMemoryContentPolicy {
    enum Decision: Equatable {
        case allowed
        case rejected(reason: String)
    }

    private static let webpageInstructionSignals = [
        "cookie policy",
        "accept all cookies",
        "javascript:",
        "click here to continue",
        "enable notifications",
        "subscribe to our newsletter",
        "terms of service",
        "privacy policy",
        "sign in to continue",
        "captcha",
        "verify you are human"
    ]

    static func evaluateForStorage(_ content: String, source: DexterMemorySource) -> Decision {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            return .rejected(reason: "Memory content is empty.")
        }

        if trimmedContent.count > 4_000 {
            return .rejected(reason: "Memory content is too long to store safely.")
        }

        let lowered = trimmedContent.lowercased()
        if webpageInstructionSignals.contains(where: { lowered.contains($0) }) {
            return .rejected(reason: "Dexter does not store webpage instructions as user memory.")
        }

        let httpLinkCount = lowered.components(separatedBy: "http").count - 1
        if httpLinkCount >= 3 {
            return .rejected(reason: "Dexter does not store link-heavy webpage content as memory.")
        }

        if source == .inferredObservation && trimmedContent.count < 12 {
            return .rejected(reason: "Inferred memory is too vague to store.")
        }

        return .allowed
    }
}
