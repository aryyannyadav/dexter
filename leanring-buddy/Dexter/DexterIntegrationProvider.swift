//
//  DexterIntegrationProvider.swift
//  leanring-buddy
//
//  Lightweight integration surface: authorized macOS/browser/filesystem signals → Context Engine graph.
//  External mutations remain Tool Gateway only (providers are read-only).
//

import Foundation

enum DexterIntegrationDomain: String, Equatable, CaseIterable {
    case macOSApplication = "macos_application"
    case visualStudioCode = "vscode"
    case terminal = "terminal"
    case browser = "browser"
    case filesystemDocuments = "documents"
    case gitHub = "github"
    case calendar = "calendar"
    case communication = "communication"
}

struct DexterIntegrationLinkage: Equatable {
    var workflowEntityIdentifier: String?
    var projectEntityIdentifier: String?
    var taskEntityIdentifier: String?
}

struct DexterIntegrationProviderInput: Equatable {
    let authorizedInput: DexterAuthorizedPersonalContextInput
    let linkage: DexterIntegrationLinkage
}

protocol DexterIntegrationProvider {
    var domain: DexterIntegrationDomain { get }
    func contribute(context: DexterIntegrationProviderInput) -> DexterPersonalContextIntegrationResult?
}

enum DexterIntegrationProviderRegistry {
    static let allProviders: [DexterIntegrationProvider] = [
        VisualStudioCodeIntegrationProvider(),
        TerminalIntegrationProvider(),
        BrowserIntegrationProvider(),
        GitHubIntegrationProvider(),
        DocumentsIntegrationProvider(),
        CalendarIntegrationProvider(),
        CommunicationIntegrationProvider()
    ]

    static func collectContributions(context: DexterIntegrationProviderInput) -> [DexterPersonalContextIntegrationResult] {
        allProviders.compactMap { provider in
            provider.contribute(context: context)
        }
    }
}

struct DexterCrossApplicationContext: Equatable {
    let activeDomains: [DexterIntegrationDomain]
    let relationshipSummaries: [String]

    var promptSection: String {
        if relationshipSummaries.isEmpty {
            return "none"
        }
        let domainList = activeDomains.map(\.rawValue).joined(separator: ", ")
        var lines = ["Active integrations: \(domainList)"]
        lines.append(contentsOf: relationshipSummaries.map { "- \($0)" })
        return lines.joined(separator: "\n")
    }

    static let empty = DexterCrossApplicationContext(activeDomains: [], relationshipSummaries: [])
}

enum DexterCrossApplicationContextComposer {
    static func compose(
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterCrossApplicationContext {
        var summaries: [String] = []
        var domains: [DexterIntegrationDomain] = []

        for sourceLabel in graph.authorizedSourceLabels {
            if let domain = DexterIntegrationDomain(rawValue: sourceLabel) {
                domains.append(domain)
            }
        }

        if let vscodeFile = graph.entities.first(where: { $0.id == "vscode:file" }) {
            summaries.append("Editor file: \(vscodeFile.title)\(vscodeFile.detail.map { " (\($0))" } ?? "")")
        }
        if let vscodeWorkspace = graph.entities.first(where: { $0.id == "vscode:workspace" }) {
            summaries.append("Project/workspace: \(vscodeWorkspace.title)")
        }
        if let diagnostics = graph.entities.first(where: { $0.id == "vscode:diagnostics" }) {
            summaries.append("Editor signals: \(diagnostics.detail ?? diagnostics.title)")
        }

        if let application = graph.entities.first(where: { $0.kind == .application && $0.id != "application:vscode" }) {
            summaries.append("Frontmost app: \(application.title)\(application.detail.map { " — \($0)" } ?? "")")
        }

        if let task = graph.entities.first(where: { $0.id == "task:current" })?.detail?.nonEmptyTrimmedValue {
            summaries.append("Current task memory: \(task)")
        }

        if let workflow = graph.entities.first(where: { $0.kind == .workflow })?.detail?.nonEmptyTrimmedValue {
            summaries.append("Workflow: \(workflow)")
        }

        if let lastAction = authorizedInput.recentActionSummaries.last {
            summaries.append("Recent Dexter action: \(lastAction)")
        }

        if let selectedText = authorizedInput.selectedTextSnippet?.nonEmptyTrimmedValue {
            let clipped = String(selectedText.prefix(120))
            summaries.append("Selected text snippet: \(clipped)")
        }

        if let lastExchange = authorizedInput.recentConversationExchanges.last {
            summaries.append("Last conversation topic: “\(lastExchange.userTranscript)”")
        }

        return DexterCrossApplicationContext(
            activeDomains: domains,
            relationshipSummaries: summaries
        )
    }
}
