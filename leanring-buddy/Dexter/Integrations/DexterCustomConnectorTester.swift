//
//  DexterCustomConnectorTester.swift
//  leanring-buddy
//

import Foundation

enum DexterCustomConnectorTester {
    static func testConnection(
        configuration: DexterCustomConnectorConfiguration,
        openClawHealthMonitor: OpenClawGatewayHealthMonitor
    ) async -> DexterIntegrationSnapshot {
        switch configuration.kind {
        case .openClaw:
            return await testOpenClawCustomConnector(
                configuration: configuration,
                openClawHealthMonitor: openClawHealthMonitor
            )
        case .mcp:
            return await testMCPCustomConnector(configuration: configuration)
        }
    }

    private static func testOpenClawCustomConnector(
        configuration: DexterCustomConnectorConfiguration,
        openClawHealthMonitor: OpenClawGatewayHealthMonitor
    ) async -> DexterIntegrationSnapshot {
        await openClawHealthMonitor.refreshHealthIfNeeded(force: true)

        switch openClawHealthMonitor.connectionState {
        case .connected:
            let discovery = DexterOpenClawCapabilityDiscovery.report(
                gatewayConnected: true,
                nodeSnapshot: openClawHealthMonitor.preferredNodeSnapshot
            )
            return DexterIntegrationSnapshot(
                connectionState: .connected,
                statusDetail: openClawHealthMonitor.statusLine,
                capabilities: mapOpenClawCapabilities(discovery)
            )
        case .connecting:
            return DexterIntegrationSnapshot(
                connectionState: .connecting,
                statusDetail: openClawHealthMonitor.statusLine,
                capabilities: []
            )
        case .unavailable:
            return DexterIntegrationSnapshot(
                connectionState: .unsupported,
                statusDetail: "OpenClaw CLI is not installed on this Mac.",
                capabilities: []
            )
        case .disconnected:
            return DexterIntegrationSnapshot(
                connectionState: .notConnected,
                statusDetail: configuration.serverURLString.isEmpty
                    ? "Gateway is offline."
                    : "Gateway offline — configured endpoint: \(configuration.serverURLString)",
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

    private static func testMCPCustomConnector(
        configuration: DexterCustomConnectorConfiguration
    ) async -> DexterIntegrationSnapshot {
        switch configuration.transport {
        case .remoteServerURL:
            return await testReachableHTTPServer(
                urlString: configuration.serverURLString,
                keychainAccount: configuration.keychainAccount
            )
        case .localCommand:
            return testLocalCommand(configuration.localCommand)
        }
    }

    private static func testReachableHTTPServer(
        urlString: String,
        keychainAccount: String
    ) async -> DexterIntegrationSnapshot {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURLString.isEmpty else {
            return DexterIntegrationSnapshot(
                connectionState: .notConnected,
                statusDetail: "Add a server URL to test reachability.",
                capabilities: []
            )
        }

        guard let url = normalizedURL(from: trimmedURLString) else {
            return DexterIntegrationSnapshot(
                connectionState: .error(message: "Invalid server URL."),
                statusDetail: "Could not parse the server URL.",
                capabilities: []
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8

        if let credential = DexterKeychainCredentialStore.loadUTF8Secret(account: keychainAccount) {
            request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return DexterIntegrationSnapshot(
                    connectionState: .error(message: "No HTTP response."),
                    statusDetail: nil,
                    capabilities: []
                )
            }

            if (200...299).contains(httpResponse.statusCode) {
                return DexterIntegrationSnapshot(
                    connectionState: .connected,
                    statusDetail: "Server responded (HTTP \(httpResponse.statusCode)). MCP wire protocol is not negotiated by Dexter yet.",
                    capabilities: [
                        DexterConnectorCapability(
                            id: "reachability",
                            displayName: "Endpoint reachable",
                            isAvailable: true,
                            detail: "HTTP \(httpResponse.statusCode)"
                        )
                    ]
                )
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                let hasCredential = DexterKeychainCredentialStore.loadUTF8Secret(account: keychainAccount) != nil
                return DexterIntegrationSnapshot(
                    connectionState: hasCredential ? .error(message: "HTTP \(httpResponse.statusCode)") : .needsAuthentication,
                    statusDetail: "Server requires authentication (HTTP \(httpResponse.statusCode)).",
                    capabilities: []
                )
            }

            return DexterIntegrationSnapshot(
                connectionState: .error(message: "HTTP \(httpResponse.statusCode)"),
                statusDetail: "Server returned HTTP \(httpResponse.statusCode).",
                capabilities: []
            )
        } catch {
            return DexterIntegrationSnapshot(
                connectionState: .notConnected,
                statusDetail: "Could not reach the server.",
                capabilities: []
            )
        }
    }

    private static func testLocalCommand(_ command: String) -> DexterIntegrationSnapshot {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            return DexterIntegrationSnapshot(
                connectionState: .notConnected,
                statusDetail: "Add a local command to test.",
                capabilities: []
            )
        }

        let isExecutable = FileManager.default.isExecutableFile(atPath: trimmedCommand)
        if isExecutable {
            return DexterIntegrationSnapshot(
                connectionState: .connected,
                statusDetail: "Executable found. Dexter does not run MCP wire protocol over stdio yet.",
                capabilities: [
                    DexterConnectorCapability(
                        id: "executable",
                        displayName: "Local command exists",
                        isAvailable: true,
                        detail: trimmedCommand
                    )
                ]
            )
        }

        return DexterIntegrationSnapshot(
            connectionState: .notConnected,
            statusDetail: "Command is not executable at the configured path.",
            capabilities: []
        )
    }

    private static func normalizedURL(from urlString: String) -> URL? {
        if let url = URL(string: urlString), url.scheme != nil {
            return url
        }
        return URL(string: "http://\(urlString)")
    }

    private static func mapOpenClawCapabilities(
        _ discovery: DexterOpenClawCapabilityDiscoveryReport
    ) -> [DexterConnectorCapability] {
        discovery.capabilities.map { capabilityStatus in
            DexterConnectorCapability(
                id: capabilityStatus.capability.rawValue,
                displayName: capabilityStatus.capability.displayName,
                isAvailable: capabilityStatus.isAvailable,
                detail: capabilityStatus.detail
            )
        }
    }
}
