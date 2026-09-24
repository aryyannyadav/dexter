//
//  DexterBrowserState.swift
//  leanring-buddy
//

import Foundation

struct DexterBrowserStateSnapshot: Equatable, Codable {
    let url: String?
    let title: String?
    let pageIdentity: String?
    let relevantText: String?
    let selectedElementDescription: String?
    let currentTaskDescription: String?
    let availability: DexterContextAvailability

    static let empty = DexterBrowserStateSnapshot(
        url: nil,
        title: nil,
        pageIdentity: nil,
        relevantText: nil,
        selectedElementDescription: nil,
        currentTaskDescription: nil,
        availability: .notApplicable
    )
}

enum DexterBrowserRuntimeStateParser {
    static func parse(fromRawOutput rawOutput: String?) -> DexterBrowserStateSnapshot {
        guard let rawOutput, !rawOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }

        if let jsonObject = parseJSONObject(from: rawOutput) {
            return DexterBrowserStateSnapshot(
                url: stringValue(jsonObject, keys: ["url", "pageUrl", "href", "location"]),
                title: stringValue(jsonObject, keys: ["title", "pageTitle", "documentTitle"]),
                pageIdentity: stringValue(jsonObject, keys: ["pageIdentity", "pageId", "origin"]),
                relevantText: stringValue(jsonObject, keys: ["text", "content", "bodyText", "relevantText"]),
                selectedElementDescription: stringValue(jsonObject, keys: ["selectedElement", "selection"]),
                currentTaskDescription: nil,
                availability: .available
            )
        }

        if let url = firstURL(in: rawOutput) {
            return DexterBrowserStateSnapshot(
                url: url,
                title: nil,
                pageIdentity: URL(string: url)?.host,
                relevantText: nil,
                selectedElementDescription: nil,
                currentTaskDescription: nil,
                availability: .available
            )
        }

        return .empty
    }

    private static func parseJSONObject(from rawOutput: String) -> [String: Any]? {
        guard let data = rawOutput.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func stringValue(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func firstURL(in text: String) -> String? {
        let pattern = #"https?://[^\s\"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[swiftRange])
    }
}

enum DexterBrowserStateCollector {
    static func collect(
        activeApplication: DexterActiveApplicationContext?,
        activeWindow: DexterActiveWindowContext?,
        selectedText: DexterSelectedTextContext?,
        browserContext: DexterBrowserContext?,
        currentTaskDescription: String?,
        pointerSemanticTargetLabel: String?
    ) -> DexterBrowserStateSnapshot {
        let isBrowserFrontmost = browserContext?.availability == .available
            || isBrowserApplicationName(activeApplication?.localizedName)

        guard isBrowserFrontmost else {
            return DexterBrowserStateSnapshot(
                url: nil,
                title: activeWindow?.title,
                pageIdentity: nil,
                relevantText: nil,
                selectedElementDescription: pointerSemanticTargetLabel,
                currentTaskDescription: currentTaskDescription,
                availability: .notApplicable
            )
        }

        let windowTitle = activeWindow?.title ?? browserContext?.inferredPageTitle
        let urlFromTitle = browserContext?.inferredPageURL
            ?? windowTitle.flatMap { inferURL(fromWindowTitle: $0) }

        return DexterBrowserStateSnapshot(
            url: urlFromTitle,
            title: windowTitle,
            pageIdentity: browserContext?.pageIdentity
                ?? urlFromTitle.flatMap { URL(string: $0)?.host }
                ?? windowTitle,
            relevantText: selectedText?.selectedText,
            selectedElementDescription: pointerSemanticTargetLabel ?? selectedText?.selectedText,
            currentTaskDescription: currentTaskDescription,
            availability: .available
        )
    }

    static func isBrowserApplicationName(_ applicationName: String?) -> Bool {
        let lowered = applicationName?.lowercased() ?? ""
        return lowered.contains("safari")
            || lowered.contains("chrome")
            || lowered.contains("firefox")
            || lowered.contains("edge")
            || lowered.contains("brave")
    }

    private static func inferURL(fromWindowTitle windowTitle: String) -> String? {
        if windowTitle.lowercased().hasPrefix("http://") || windowTitle.lowercased().hasPrefix("https://") {
            return windowTitle
        }
        return nil
    }
}
