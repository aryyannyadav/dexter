//
//  DexterIntegrationProviders.swift
//  leanring-buddy
//

import Foundation

enum DexterVisualStudioCodeWindowParser {
    struct ParsedWindow: Equatable {
        let workspaceName: String?
        let fileName: String?
        let suggestsErrorOrProblems: Bool
    }

    static func parse(windowTitle: String) -> ParsedWindow {
        let trimmedTitle = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutDirtyMarker = trimmedTitle.hasPrefix("●")
            ? trimmedTitle.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedTitle

        let components = withoutDirtyMarker
            .split(separator: "—", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let suggestsError = withoutDirtyMarker.lowercased().contains("error")
            || withoutDirtyMarker.lowercased().contains("problem")

        if components.count >= 2 {
            let fileName = components.first.map { String($0) }
            let workspaceName = components.dropFirst().first.map { String($0) }
            return ParsedWindow(
                workspaceName: workspaceName,
                fileName: fileName,
                suggestsErrorOrProblems: suggestsError
            )
        }

        return ParsedWindow(
            workspaceName: nil,
            fileName: withoutDirtyMarker.isEmpty ? nil : String(withoutDirtyMarker),
            suggestsErrorOrProblems: suggestsError
        )
    }
}

struct VisualStudioCodeIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .visualStudioCode

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let authorizedInput = context.authorizedInput
        let applicationName = authorizedInput.activeApplicationName?.lowercased() ?? ""
        let bundleIdentifier = authorizedInput.activeApplicationBundleIdentifier?.lowercased() ?? ""
        let isVSCode = bundleIdentifier.contains("com.microsoft.vscode")
            || applicationName.contains("visual studio code")
            || applicationName == "code"

        guard isVSCode else { return nil }

        let windowTitle = authorizedInput.activeWindowTitle ?? "Visual Studio Code"
        let parsedWindow = DexterVisualStudioCodeWindowParser.parse(windowTitle: windowTitle)

        var entities: [DexterContextGraphEntity] = [
            DexterContextGraphEntity(
                id: "application:vscode",
                kind: .application,
                title: "Visual Studio Code",
                detail: windowTitle,
                sourceIntegration: domain.rawValue
            )
        ]

        if let fileName = parsedWindow.fileName {
            entities.append(
                DexterContextGraphEntity(
                    id: "vscode:file",
                    kind: .project,
                    title: fileName,
                    detail: parsedWindow.workspaceName,
                    sourceIntegration: domain.rawValue
                )
            )
        }

        if let workspaceName = parsedWindow.workspaceName {
            entities.append(
                DexterContextGraphEntity(
                    id: "vscode:workspace",
                    kind: .project,
                    title: workspaceName,
                    detail: "VS Code workspace",
                    sourceIntegration: domain.rawValue
                )
            )
        }

        if parsedWindow.suggestsErrorOrProblems
            || authorizedInput.selectedTextSnippet?.lowercased().contains("error") == true {
            entities.append(
                DexterContextGraphEntity(
                    id: "vscode:diagnostics",
                    kind: .memory,
                    title: "Possible error context",
                    detail: "Window or selection suggests an error or problem.",
                    sourceIntegration: domain.rawValue
                )
            )
        }

        var relationships: [DexterContextGraphRelationship] = []
        if let workflowEntityIdentifier = context.linkage.workflowEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: workflowEntityIdentifier,
                    relationship: .workflowToApplication,
                    toEntityIdentifier: "application:vscode"
                )
            )
        }
        if entities.contains(where: { $0.id == "vscode:workspace" }),
           entities.contains(where: { $0.id == "vscode:file" }) {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: "vscode:workspace",
                    relationship: .contains,
                    toEntityIdentifier: "vscode:file"
                )
            )
        }
        if let projectEntityIdentifier = context.linkage.projectEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: projectEntityIdentifier,
                    relationship: .uses,
                    toEntityIdentifier: "application:vscode"
                )
            )
        }

        return DexterPersonalContextIntegrationResult(
            entities: entities,
            relationships: relationships,
            sourceLabel: domain.rawValue
        )
    }
}

struct TerminalIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .terminal

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let authorizedInput = context.authorizedInput
        let applicationName = authorizedInput.activeApplicationName?.lowercased() ?? ""
        let bundleIdentifier = authorizedInput.activeApplicationBundleIdentifier?.lowercased() ?? ""

        let isTerminal = bundleIdentifier.contains("com.apple.terminal")
            || bundleIdentifier.contains("com.googlecode.iterm")
            || bundleIdentifier.contains("com.apple.iterm")
            || applicationName.contains("terminal")
            || applicationName.contains("iterm")

        guard isTerminal else { return nil }

        let entity = DexterContextGraphEntity(
            id: "application:terminal",
            kind: .application,
            title: authorizedInput.activeApplicationName ?? "Terminal",
            detail: authorizedInput.activeWindowTitle,
            sourceIntegration: domain.rawValue
        )

        var relationships: [DexterContextGraphRelationship] = []
        if let workflowEntityIdentifier = context.linkage.workflowEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: workflowEntityIdentifier,
                    relationship: .workflowToApplication,
                    toEntityIdentifier: entity.id
                )
            )
        }

        return DexterPersonalContextIntegrationResult(
            entities: [entity],
            relationships: relationships,
            sourceLabel: domain.rawValue
        )
    }
}

struct BrowserIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .browser

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let authorizedInput = context.authorizedInput
        let applicationName = authorizedInput.activeApplicationName?.lowercased() ?? ""
        let isBrowser = applicationName.contains("safari")
            || applicationName.contains("chrome")
            || applicationName.contains("firefox")
            || applicationName.contains("edge")
            || applicationName.contains("brave")

        guard isBrowser || authorizedInput.browserPageURL != nil else { return nil }

        let pageDetail = [
            authorizedInput.browserPageTitle,
            authorizedInput.browserPageURL
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " — ")

        let entity = DexterContextGraphEntity(
            id: "application:browser",
            kind: .application,
            title: authorizedInput.activeApplicationName ?? "Browser",
            detail: pageDetail.isEmpty ? authorizedInput.activeWindowTitle : pageDetail,
            sourceIntegration: domain.rawValue
        )

        var relationships: [DexterContextGraphRelationship] = []
        if let workflowEntityIdentifier = context.linkage.workflowEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: workflowEntityIdentifier,
                    relationship: .workflowToApplication,
                    toEntityIdentifier: entity.id
                )
            )
        }

        return DexterPersonalContextIntegrationResult(
            entities: [entity],
            relationships: relationships,
            sourceLabel: domain.rawValue
        )
    }
}

struct GitHubIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .gitHub

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let pageURL = context.authorizedInput.browserPageURL?.lowercased() ?? ""
        guard pageURL.contains("github.com") else { return nil }

        let title = context.authorizedInput.browserPageTitle ?? "GitHub"
        let entity = DexterContextGraphEntity(
            id: "github:page",
            kind: .project,
            title: title,
            detail: context.authorizedInput.browserPageURL,
            sourceIntegration: domain.rawValue
        )

        var relationships: [DexterContextGraphRelationship] = []
        if context.authorizedInput.activeApplicationName != nil {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: "application:browser",
                    relationship: .uses,
                    toEntityIdentifier: entity.id
                )
            )
        }

        return DexterPersonalContextIntegrationResult(
            entities: [entity],
            relationships: relationships,
            sourceLabel: domain.rawValue
        )
    }
}

struct DocumentsIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .filesystemDocuments

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let authorizedInput = context.authorizedInput
        let windowTitle = authorizedInput.activeWindowTitle?.lowercased() ?? ""
        let documentSignals = [".md", ".txt", ".swift", ".pdf", "documents/", "notes"]
        let looksLikeDocument = documentSignals.contains { windowTitle.contains($0) }
            || authorizedInput.retrievedMemories.contains { $0.type == .project }

        guard looksLikeDocument else { return nil }

        let detail = authorizedInput.activeWindowTitle ?? "Document context"
        let entity = DexterContextGraphEntity(
            id: "project:documents:active",
            kind: .project,
            title: "Documents",
            detail: detail,
            sourceIntegration: domain.rawValue
        )

        var relationships: [DexterContextGraphRelationship] = []
        if let projectEntityIdentifier = context.linkage.projectEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: projectEntityIdentifier,
                    relationship: .contains,
                    toEntityIdentifier: entity.id
                )
            )
        }
        if let taskEntityIdentifier = context.linkage.taskEntityIdentifier {
            relationships.append(
                DexterContextGraphRelationship(
                    fromEntityIdentifier: entity.id,
                    relationship: .projectToTask,
                    toEntityIdentifier: taskEntityIdentifier
                )
            )
        }

        return DexterPersonalContextIntegrationResult(
            entities: [entity],
            relationships: relationships,
            sourceLabel: domain.rawValue
        )
    }
}

struct CalendarIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .calendar

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let bundleIdentifier = context.authorizedInput.activeApplicationBundleIdentifier?.lowercased() ?? ""
        let applicationName = context.authorizedInput.activeApplicationName?.lowercased() ?? ""
        let isCalendar = bundleIdentifier.contains("com.apple.ical")
            || applicationName.contains("calendar")

        guard isCalendar else { return nil }

        let entity = DexterContextGraphEntity(
            id: "application:calendar",
            kind: .application,
            title: context.authorizedInput.activeApplicationName ?? "Calendar",
            detail: context.authorizedInput.activeWindowTitle,
            sourceIntegration: domain.rawValue
        )

        return DexterPersonalContextIntegrationResult(
            entities: [entity],
            relationships: [],
            sourceLabel: domain.rawValue
        )
    }
}

struct CommunicationIntegrationProvider: DexterIntegrationProvider {
    let domain: DexterIntegrationDomain = .communication

    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult? {
        let applicationName = context.authorizedInput.activeApplicationName?.lowercased() ?? ""
        let bundleIdentifier = context.authorizedInput.activeApplicationBundleIdentifier?.lowercased() ?? ""

        let communicationSignals = ["mail", "messages", "slack", "discord", "teams", "zoom"]
        let isCommunication = communicationSignals.contains { applicationName.contains($0) }
            || bundleIdentifier.contains("com.apple.mail")
            || bundleIdentifier.contains("com.tinyspeck.slackmacgap")

        guard isCommunication else { return nil }

        let entity = DexterContextGraphEntity(
            id: "application:communication",
            kind: .application,
            title: context.authorizedInput.activeApplicationName ?? "Communication",
            detail: context.authorizedInput.activeWindowTitle,
            sourceIntegration: domain.rawValue
        )

        return DexterPersonalContextIntegrationResult(
            entities: [entity],
            relationships: [],
            sourceLabel: domain.rawValue
        )
    }
}
