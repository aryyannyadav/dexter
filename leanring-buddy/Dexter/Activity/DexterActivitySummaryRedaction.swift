//
//  DexterActivitySummaryRedaction.swift
//  leanring-buddy
//

import Foundation

enum DexterActivitySummaryRedaction {
    static func safeUserFacingText(_ text: String, maxLength: Int = 240) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch DexterMemoryContentPolicy.evaluateForStorage(trimmed, source: .explicitUserUtterance) {
        case .rejected:
            return nil
        case .allowed:
            let redacted = DexterObservabilityRedaction.redact(trimmed)
            if redacted.count <= maxLength {
                return redacted
            }
            return String(redacted.prefix(maxLength - 1)) + "…"
        }
    }

    static func displaySafePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return (path as NSString).lastPathComponent
    }
}
