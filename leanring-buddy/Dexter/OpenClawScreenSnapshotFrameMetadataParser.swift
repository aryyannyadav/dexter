//
//  OpenClawScreenSnapshotFrameMetadataParser.swift
//  leanring-buddy
//

import Foundation

struct OpenClawScreenSnapshotFrameMetadata: Equatable {
    let displayFrameId: String?
    let frameId: String?
    let refWidth: Int?
    let observationId: String?
}

/// Parses provider frame metadata from `screen.snapshot` node output (JSON or embedded JSON).
enum OpenClawScreenSnapshotFrameMetadataParser {
    static func parse(from combinedOutput: String) -> OpenClawScreenSnapshotFrameMetadata? {
        let trimmedOutput = combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else { return nil }

        if let direct = parseJSONObject(trimmedOutput) {
            return metadata(from: direct)
        }

        if let embeddedJSON = extractEmbeddedJSONObject(from: trimmedOutput),
           let object = parseJSONObject(embeddedJSON) {
            return metadata(from: object)
        }

        return nil
    }

    private static func parseJSONObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func extractEmbeddedJSONObject(from text: String) -> String? {
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return nil
        }
        let candidate = String(text[startIndex...endIndex])
        return parseJSONObject(candidate) != nil ? candidate : nil
    }

    private static func metadata(from object: [String: Any]) -> OpenClawScreenSnapshotFrameMetadata {
        let nestedResult = object["result"] as? [String: Any] ?? object["data"] as? [String: Any]
        let sources: [[String: Any]] = [object, nestedResult].compactMap { $0 }

        var displayFrameId: String?
        var frameId: String?
        var refWidth: Int?
        var observationId: String?

        for source in sources {
            displayFrameId = displayFrameId ?? stringValue(source["displayFrameId"])
            frameId = frameId ?? stringValue(source["frameId"])
            observationId = observationId ?? stringValue(source["observationId"])
            refWidth = refWidth ?? intValue(source["refWidth"]) ?? intValue(source["width"])
        }

        return OpenClawScreenSnapshotFrameMetadata(
            displayFrameId: displayFrameId,
            frameId: frameId,
            refWidth: refWidth,
            observationId: observationId
        )
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let stringValue = value as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String { return Int(stringValue) }
        return nil
    }
}
