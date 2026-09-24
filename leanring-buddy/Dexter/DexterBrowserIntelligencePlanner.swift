//
//  DexterBrowserIntelligencePlanner.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

/// Plans browser actions routed through OpenClaw `browser.proxy` (Intent → action; execution uses existing pipeline).
enum DexterBrowserIntelligencePlanner {
    /// Search utterances that map to `browser.proxy` search actions (used for ACT routing; not generic web research).
    static func isExecutableSearchUtterance(normalizedUserMessage: String) -> Bool {
        planSearch(normalizedUserMessage) != nil
    }

    static func planAction(
        normalizedUserMessage: String,
        context: DexterContext
    ) -> DexterActionPlanningOutcome {
        if let openAction = planOpen(normalizedUserMessage) {
            return .action(openAction)
        }

        if let searchAction = planSearch(normalizedUserMessage) {
            return .action(searchAction)
        }

        if let navigateAction = planDocumentationSearch(normalizedUserMessage) {
            return .action(navigateAction)
        }

        if normalizedUserMessage == "read this page" || normalizedUserMessage == "read this" {
            return .action(DexterActionFactory.browserReadPage())
        }

        if normalizedUserMessage == "go back" || normalizedUserMessage == "browser back" {
            return .action(DexterActionFactory.browserBack())
        }

        if normalizedUserMessage == "go forward" || normalizedUserMessage == "browser forward" {
            return .action(DexterActionFactory.browserForward())
        }

        if DexterPointerControlWorkflow.matchesPointerActIntent(normalizedUserMessage: normalizedUserMessage)
            || normalizedUserMessage == "click this"
            || normalizedUserMessage == "click it" {
            return planBrowserClick(context: context)
        }

        if normalizedUserMessage.hasPrefix("type ")
            || normalizedUserMessage.contains("type this") {
            let text = extractTypeText(from: normalizedUserMessage)
            if let text {
                return .action(DexterActionFactory.browserType(text: text))
            }
        }

        return .notAnAction
    }

    private static func planOpen(_ normalizedUserMessage: String) -> DexterAction? {
        guard normalizedUserMessage.hasPrefix("open ") else { return nil }
        let target = normalizedUserMessage.replacingOccurrences(of: "open ", with: "").trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }

        if target.hasPrefix("http://") || target.hasPrefix("https://") {
            return DexterActionFactory.browserOpen(url: target, verificationHint: target)
        }

        if let url = DexterBrowserSiteResolver.url(forSiteName: target) {
            return DexterActionFactory.browserOpen(url: url, verificationHint: URL(string: url)?.host ?? target)
        }

        return DexterActionFactory.browserOpen(
            url: "https://www.google.com/search?q=\(target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? target)",
            verificationHint: target
        )
    }

    private static func planSearch(_ normalizedUserMessage: String) -> DexterAction? {
        let prefixes = ["search for ", "search ", "look up "]
        guard let prefix = prefixes.first(where: { normalizedUserMessage.hasPrefix($0) }) else {
            return nil
        }
        let query = normalizedUserMessage.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return nil }
        return DexterActionFactory.browserSearch(query: query)
    }

    private static func planDocumentationSearch(_ normalizedUserMessage: String) -> DexterAction? {
        guard normalizedUserMessage.contains("find the documentation")
            || normalizedUserMessage.contains("find documentation")
            || normalizedUserMessage.contains("find the docs") else {
            return nil
        }
        let topic = normalizedUserMessage
            .replacingOccurrences(of: "find the documentation", with: "")
            .replacingOccurrences(of: "find documentation", with: "")
            .replacingOccurrences(of: "find the docs", with: "")
            .replacingOccurrences(of: "for ", with: "")
            .trimmingCharacters(in: .whitespaces)
        let query = topic.isEmpty ? "documentation" : "\(topic) documentation"
        return DexterActionFactory.browserSearch(query: query)
    }

    private static func planBrowserClick(context: DexterContext) -> DexterActionPlanningOutcome {
        guard let pointerLocation = DexterPointerControlWorkflow.validatedPointerLocationInScreenSpace(for: context) else {
            return .unsupported(message: DexterPointerControlWorkflow.pointFirstMessage)
        }
        let label = DexterPointerControlWorkflow.controlLabelForConfirmation(from: context)
        return .action(
            DexterActionFactory.browserClick(
                x: String(format: "%.0f", pointerLocation.x),
                y: String(format: "%.0f", pointerLocation.y),
                label: label
            )
        )
    }

    private static func extractTypeText(from normalizedUserMessage: String) -> String? {
        if normalizedUserMessage.hasPrefix("type ") {
            let text = normalizedUserMessage.replacingOccurrences(of: "type ", with: "")
            return text.isEmpty ? nil : text
        }
        return nil
    }
}

enum DexterBrowserSiteResolver {
    static func url(forSiteName siteName: String) -> String? {
        let normalized = siteName.lowercased().replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "youtube": return "https://www.youtube.com"
        case "google": return "https://www.google.com"
        case "github": return "https://github.com"
        case "apple": return "https://www.apple.com"
        case "reddit": return "https://www.reddit.com"
        default:
            if normalized.contains(".") {
                return normalized.hasPrefix("http") ? normalized : "https://\(normalized)"
            }
            return nil
        }
    }
}
