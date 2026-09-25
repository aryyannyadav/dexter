//
//  DexterBuiltInConnectors.swift
//  leanring-buddy
//

import Foundation

extension DexterOpenClawCapabilityKind {
    var displayName: String {
        switch self {
        case .computerAct: return "Computer actions"
        case .screenSnapshot: return "Screen snapshot"
        case .browserProxy: return "Browser proxy"
        case .systemRun: return "System run"
        case .file: return "File tools"
        case .canvas: return "Canvas"
        case .mcp: return "MCP"
        case .localInference: return "Local inference"
        }
    }
}

struct DexterOpenClawGatewayConnector: DexterConnector {
    let integrationIdentifier = "openclaw-gateway"
    let displayName = "OpenClaw Gateway"
    let integrationKind: DexterIntegration.Kind = .operational

    private let healthMonitor: OpenClawGatewayHealthMonitor

    init(healthMonitor: OpenClawGatewayHealthMonitor) {
        self.healthMonitor = healthMonitor
    }

    func fetchSnapshot(context: DexterIntegrationContext) async -> DexterIntegrationSnapshot {
        await healthMonitor.refreshHealthIfNeeded(force: false)

        switch healthMonitor.connectionState {
        case .connected:
            let discovery = DexterOpenClawCapabilityDiscovery.report(
                gatewayConnected: true,
                nodeSnapshot: healthMonitor.preferredNodeSnapshot
            )
            return DexterIntegrationSnapshot(
                connectionState: .connected,
                statusDetail: healthMonitor.statusLine,
                capabilities: discovery.capabilities.map { capabilityStatus in
                    DexterConnectorCapability(
                        id: capabilityStatus.capability.rawValue,
                        displayName: capabilityStatus.capability.displayName,
                        isAvailable: capabilityStatus.isAvailable,
                        detail: capabilityStatus.detail
                    )
                }
            )
        case .connecting:
            return DexterIntegrationSnapshot(
                connectionState: .connecting,
                statusDetail: healthMonitor.statusLine,
                capabilities: []
            )
        case .unavailable:
            return DexterIntegrationSnapshot(
                connectionState: .unsupported,
                statusDetail: "Install the OpenClaw CLI to enable computer use.",
                capabilities: []
            )
        case .disconnected:
            return DexterIntegrationSnapshot(
                connectionState: .notConnected,
                statusDetail: "Gateway is offline on this Mac.",
                capabilities: []
            )
        case .error(let message):
            return DexterIntegrationSnapshot(
                connectionState: .error(message: message),
                statusDetail: message,
                capabilities: []
            )
        }
    }
}

struct DexterAmbientContextConnector: DexterConnector {
    let integrationIdentifier: String
    let displayName: String
    let integrationKind: DexterIntegration.Kind = .operational

    private let applicationNameMatchers: [String]
    private let bundleIdentifierContains: String?
    private let browserHostContains: String?

    init(
        integrationIdentifier: String,
        displayName: String,
        applicationNameMatchers: [String],
        bundleIdentifierContains: String? = nil,
        browserHostContains: String? = nil
    ) {
        self.integrationIdentifier = integrationIdentifier
        self.displayName = displayName
        self.applicationNameMatchers = applicationNameMatchers
        self.bundleIdentifierContains = bundleIdentifierContains
        self.browserHostContains = browserHostContains
    }

    func fetchSnapshot(context: DexterIntegrationContext) async -> DexterIntegrationSnapshot {
        let activeApplicationName = context.activeApplicationName?.lowercased() ?? ""
        let browserURL = context.browserPageURL?.lowercased() ?? ""

        let matchesApplication = applicationNameMatchers.contains { matcher in
            activeApplicationName.contains(matcher)
        }

        let matchesBrowser = browserHostContains.map { browserURL.contains($0) } ?? false

        if matchesApplication || matchesBrowser {
            return DexterIntegrationSnapshot(
                connectionState: .connected,
                statusDetail: "Supplying authorized context from the foreground app.",
                capabilities: [
                    DexterConnectorCapability(
                        id: "context-read",
                        displayName: "Read context",
                        isAvailable: true,
                        detail: "No OAuth — Dexter reads only authorized macOS signals."
                    )
                ]
            )
        }

        return DexterIntegrationSnapshot(
            connectionState: .notConnected,
            statusDetail: "Open \(displayName) to share context with Dexter.",
            capabilities: [
                DexterConnectorCapability(
                    id: "context-read",
                    displayName: "Read context",
                    isAvailable: false,
                    detail: "Available when the app is in the foreground."
                )
            ]
        )
    }
}

struct DexterGitHubConnector: DexterConnector {
    let integrationIdentifier = "github"
    let displayName = "GitHub"
    let integrationKind: DexterIntegration.Kind = .operational

    private static let personalAccessTokenKeychainAccount = "github-personal-access-token"

    func fetchSnapshot(context: DexterIntegrationContext) async -> DexterIntegrationSnapshot {
        if let token = DexterKeychainCredentialStore.loadUTF8Secret(account: Self.personalAccessTokenKeychainAccount) {
            return await verifyPersonalAccessToken(token, context: context)
        }

        let browserURL = context.browserPageURL?.lowercased() ?? ""
        if browserURL.contains("github.com") {
            return DexterIntegrationSnapshot(
                connectionState: .connected,
                statusDetail: "Active in browser — API token not configured.",
                capabilities: [
                    DexterConnectorCapability(
                        id: "browser-context",
                        displayName: "Browser page context",
                        isAvailable: true,
                        detail: context.browserPageTitle
                    ),
                    DexterConnectorCapability(
                        id: "api",
                        displayName: "GitHub API",
                        isAvailable: false,
                        detail: "Add a personal access token to enable API access."
                    )
                ]
            )
        }

        return DexterIntegrationSnapshot(
            connectionState: .needsAuthentication,
            statusDetail: "Add a GitHub personal access token in Integrations.",
            capabilities: [
                DexterConnectorCapability(
                    id: "api",
                    displayName: "GitHub API",
                    isAvailable: false,
                    detail: "Dexter does not implement OAuth — use a PAT stored in Keychain."
                )
            ]
        )
    }

    static func savePersonalAccessToken(_ token: String) throws {
        try DexterKeychainCredentialStore.saveUTF8Secret(token, account: personalAccessTokenKeychainAccount)
    }

    static func deletePersonalAccessToken() throws {
        try DexterKeychainCredentialStore.deleteSecret(account: personalAccessTokenKeychainAccount)
    }

    static var hasStoredPersonalAccessToken: Bool {
        DexterKeychainCredentialStore.loadUTF8Secret(account: personalAccessTokenKeychainAccount) != nil
    }

    private func verifyPersonalAccessToken(
        _ token: String,
        context: DexterIntegrationContext
    ) async -> DexterIntegrationSnapshot {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return DexterIntegrationSnapshot(
                    connectionState: .error(message: "Invalid GitHub response."),
                    statusDetail: nil,
                    capabilities: []
                )
            }

            if httpResponse.statusCode == 200 {
                return DexterIntegrationSnapshot(
                    connectionState: .connected,
                    statusDetail: "GitHub API token verified.",
                    capabilities: [
                        DexterConnectorCapability(
                            id: "api",
                            displayName: "GitHub API",
                            isAvailable: true,
                            detail: "Token validated against api.github.com."
                        )
                    ]
                )
            }

            if httpResponse.statusCode == 401 {
                return DexterIntegrationSnapshot(
                    connectionState: .needsAuthentication,
                    statusDetail: "GitHub rejected the stored token.",
                    capabilities: []
                )
            }

            return DexterIntegrationSnapshot(
                connectionState: .error(message: "HTTP \(httpResponse.statusCode)"),
                statusDetail: "GitHub API returned HTTP \(httpResponse.statusCode).",
                capabilities: []
            )
        } catch {
            return DexterIntegrationSnapshot(
                connectionState: .error(message: "Network error"),
                statusDetail: "Could not reach GitHub to verify the token.",
                capabilities: []
            )
        }
    }
}

struct DexterCustomConnectorAdapter: DexterConnector {
    let configuration: DexterCustomConnectorConfiguration
    private let healthMonitor: OpenClawGatewayHealthMonitor

    var integrationIdentifier: String { "custom-\(configuration.id.uuidString)" }
    var displayName: String { configuration.name }
    var integrationKind: DexterIntegration.Kind { .operational }

    init(configuration: DexterCustomConnectorConfiguration, healthMonitor: OpenClawGatewayHealthMonitor) {
        self.configuration = configuration
        self.healthMonitor = healthMonitor
    }

    func fetchSnapshot(context: DexterIntegrationContext) async -> DexterIntegrationSnapshot {
        await DexterCustomConnectorTester.testConnection(
            configuration: configuration,
            openClawHealthMonitor: healthMonitor
        )
    }
}

struct DexterDiscoveryReferenceConnector: DexterConnector {
    let integrationIdentifier: String
    let displayName: String
    let integrationKind: DexterIntegration.Kind = .discoveryReference

    func fetchSnapshot(context: DexterIntegrationContext) async -> DexterIntegrationSnapshot {
        DexterIntegrationSnapshot(
            connectionState: .unsupported,
            statusDetail: "Dexter does not ship a connector for this service yet.",
            capabilities: []
        )
    }
}
