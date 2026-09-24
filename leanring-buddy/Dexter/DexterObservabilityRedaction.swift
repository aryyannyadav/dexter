//
//  DexterObservabilityRedaction.swift
//  leanring-buddy
//

import Foundation

enum DexterObservabilityRedaction {
    private static let sensitiveKeyPatterns = [
        "api_key",
        "apikey",
        "password",
        "secret",
        "token",
        "authorization",
        "bearer",
        "x-dexter-proxy-key",
        "clipboard",
        "private_key"
    ]

    static func redact(_ message: String) -> String {
        var redacted = message

        redacted = redactPattern(redacted, pattern: #"sk-[A-Za-z0-9]{8,}"#, replacement: "sk-[REDACTED]")
        redacted = redactPattern(redacted, pattern: #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#, replacement: "Bearer [REDACTED]")
        redacted = redactPattern(redacted, pattern: #"([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})"#, replacement: "[REDACTED_EMAIL]")

        let lowered = redacted.lowercased()
        for keyPattern in sensitiveKeyPatterns where lowered.contains(keyPattern) {
            redacted = "[REDACTED_SENSITIVE_FIELD]"
            break
        }

        if redacted.count > 2_000 {
            redacted = String(redacted.prefix(2_000)) + "…[TRUNCATED]"
        }

        return redacted
    }

    static func safeMetadata(_ metadata: [String: String]) -> [String: String] {
        metadata.mapValues { redact($0) }
    }

    private static func redactPattern(_ text: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
