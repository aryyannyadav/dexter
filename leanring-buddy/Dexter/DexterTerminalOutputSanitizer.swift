//
//  DexterTerminalOutputSanitizer.swift
//  leanring-buddy
//

import Foundation

enum DexterTerminalOutputSanitizer {
    private static let secretPatterns: [String] = [
        #"sk-[A-Za-z0-9]{20,}"#,
        #"Bearer\s+[A-Za-z0-9._\-]+"#,
        #"ANTHROPIC_API_KEY\s*=\s*\S+"#,
        #"OPENAI_API_KEY\s*=\s*\S+"#,
        #"password\s*[:=]\s*\S+"#,
        #"api[_-]?key\s*[:=]\s*\S+"#
    ]

    static func sanitizeAndTruncate(_ rawOutput: String, maxBytes: Int = DexterTerminalCommandPolicy.maxOutputBytes) -> String {
        var sanitized = rawOutput
        for pattern in secretPatterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: .regularExpression
            )
        }

        guard let data = sanitized.data(using: .utf8) else {
            return ""
        }

        if data.count <= maxBytes {
            return sanitized
        }

        let truncatedData = data.prefix(maxBytes)
        let truncatedString = String(decoding: truncatedData, as: UTF8.self)
        return truncatedString + "\n…[output truncated]"
    }
}
