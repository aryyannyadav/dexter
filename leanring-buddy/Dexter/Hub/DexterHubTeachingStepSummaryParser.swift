//
//  DexterHubTeachingStepSummaryParser.swift
//
//  Lightweight step extraction for Hub summaries (Mac chat stays authoritative).
//

import Foundation

struct DexterHubTeachingStepPreview: Equatable {
    let index: Int
    let label: String
}

enum DexterHubTeachingStepSummaryParser {
    static func parseStepPreviews(from responseText: String, maximumSteps: Int = 4) -> [DexterHubTeachingStepPreview] {
        var previews: [DexterHubTeachingStepPreview] = []
        let lines = responseText.split(whereSeparator: \.isNewline)

        for line in lines {
            guard previews.count < maximumSteps else { break }
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            if let numbered = matchNumberedStepLine(trimmedLine) {
                previews.append(numbered)
                continue
            }
            if let stepKeyword = matchStepKeywordLine(trimmedLine) {
                previews.append(stepKeyword)
            }
        }

        return previews
    }

    static func hubSafeStepLabel(from instructionSummary: String) -> String {
        let trimmed = instructionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Follow the step on your Mac." }
        if trimmed.count <= 96 { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 96)
        return String(trimmed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func matchNumberedStepLine(_ line: String) -> DexterHubTeachingStepPreview? {
        let patterns = [
            #"^(\d+)[.)]\s+(.+)$"#,
            #"^step\s+(\d+)[:.\-–—]\s*(.+)$"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, options: [], range: range),
                  match.numberOfRanges >= 3,
                  let indexRange = Range(match.range(at: 1), in: line),
                  let labelRange = Range(match.range(at: 2), in: line),
                  let index = Int(line[indexRange])
            else { continue }
            let label = String(line[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }
            return DexterHubTeachingStepPreview(index: index, label: hubSafeStepLabel(from: label))
        }
        return nil
    }

    private static func matchStepKeywordLine(_ line: String) -> DexterHubTeachingStepPreview? {
        let lowered = line.lowercased()
        guard lowered.hasPrefix("step ") else { return nil }
        let withoutPrefix = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !withoutPrefix.isEmpty else { return nil }
        if let firstDigit = withoutPrefix.prefix(3).first(where: \.isNumber), let index = Int(String(firstDigit)) {
            let labelStart = withoutPrefix.drop(while: { $0.isNumber || $0 == "." || $0 == ":" || $0 == "-" || $0 == " " })
            let label = String(labelStart).trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty {
                return DexterHubTeachingStepPreview(index: index, label: hubSafeStepLabel(from: label))
            }
        }
        return DexterHubTeachingStepPreview(index: 1, label: hubSafeStepLabel(from: withoutPrefix))
    }
}
