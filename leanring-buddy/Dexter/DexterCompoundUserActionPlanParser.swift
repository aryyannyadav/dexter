//
//  DexterCompoundUserActionPlanParser.swift
//  leanring-buddy
//

import Foundation

/// Follow-up steps after a launch/focus clause in a compound user request (no per-app hardcoding).
enum DexterCompoundUserActionPlanParser {
    static func followUpActions(
        normalizedUserMessage: String,
        context: DexterContext,
        launchedApplicationName: String? = nil,
        inApplicationDestinationLabel: String? = nil
    ) -> [DexterAction] {
        var plannedActions: [DexterAction] = []

        if let inApplicationDestinationLabel,
           let destinationAction = userInterfaceDestinationAction(
               destinationLabel: inApplicationDestinationLabel,
               applicationName: launchedApplicationName,
               context: context
           ) {
            plannedActions.append(destinationAction)
        }

        guard let compoundTail = compoundTailClause(from: normalizedUserMessage) else {
            return plannedActions
        }

        if let navigationAction = navigationAction(
            for: compoundTail,
            context: context,
            launchedApplicationName: launchedApplicationName
        ) {
            plannedActions.append(navigationAction)
        }

        return plannedActions
    }

    private static func compoundTailClause(from normalizedUserMessage: String) -> String? {
        let boundaries = [" and ", " then ", " after that "]
        for boundary in boundaries {
            guard let range = normalizedUserMessage.range(of: boundary) else { continue }
            let tail = String(normalizedUserMessage[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return tail.isEmpty ? nil : tail
        }
        return nil
    }

    private static func navigationAction(
        for compoundTail: String,
        context: DexterContext,
        launchedApplicationName: String?
    ) -> DexterAction? {
        let normalizedTail = compoundTail
            .replacingOccurrences(of: " there", with: "")
            .replacingOccurrences(of: " please", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if matchesApplicationSettingsNavigation(normalizedTail) {
            return DexterActionFactory.openForegroundApplicationSettings(
                contextSummary: contextSummary(from: context)
            )
        }

        if let destinationLabel = DexterUserInterfaceDestinationLabelFormatter.canonicalLabel(from: normalizedTail),
           let destinationAction = userInterfaceDestinationAction(
               destinationLabel: destinationLabel,
               applicationName: launchedApplicationName,
               context: context
           ) {
            return destinationAction
        }

        return nil
    }

    private static func userInterfaceDestinationAction(
        destinationLabel: String,
        applicationName: String?,
        context: DexterContext
    ) -> DexterAction? {
        if let applicationName,
           DexterBrowserStateCollector.isBrowserApplicationName(applicationName) {
            if let siteURL = DexterBrowserSiteResolver.url(forSiteName: destinationLabel.lowercased()) {
                return DexterActionFactory.browserOpen(
                    url: siteURL,
                    verificationHint: URL(string: siteURL)?.host ?? destinationLabel
                )
            }
            let searchQuery = destinationLabel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destinationLabel
            return DexterActionFactory.browserOpen(
                url: "https://www.google.com/search?q=\(searchQuery)",
                verificationHint: destinationLabel
            )
        }

        return DexterActionFactory.activateUserInterfaceDestination(
            label: destinationLabel,
            applicationName: applicationName,
            contextSummary: contextSummary(from: context)
        )
    }

    private static func matchesApplicationSettingsNavigation(_ normalizedTail: String) -> Bool {
        let settingsPhrases = [
            "open settings",
            "go to settings",
            "open preferences",
            "go to preferences",
            "open the settings",
            "open app settings"
        ]
        return settingsPhrases.contains(where: { normalizedTail.hasPrefix($0) || normalizedTail == $0 })
    }

    private static func contextSummary(from context: DexterContext) -> String {
        let activeApplicationName = context.activeApplication.localizedName ?? "unknown app"
        let activeWindowTitle = context.activeWindow.title ?? "unknown window"
        return "Active app: \(activeApplicationName). Active window: \(activeWindowTitle)."
    }
}
