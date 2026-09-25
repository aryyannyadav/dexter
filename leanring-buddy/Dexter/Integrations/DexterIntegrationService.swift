//
//  DexterIntegrationService.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterIntegrationService: ObservableObject {
    @Published private(set) var integrations: [DexterIntegration] = []
    @Published private(set) var isRefreshing = false

    private let healthMonitor: OpenClawGatewayHealthMonitor
    private let customConfigurationStore: DexterCustomConnectorConfigurationStore

    init(
        healthMonitor: OpenClawGatewayHealthMonitor,
        customConfigurationStore: DexterCustomConnectorConfigurationStore = .shared
    ) {
        self.healthMonitor = healthMonitor
        self.customConfigurationStore = customConfigurationStore
    }

    private func makeRegistry() -> DexterIntegrationRegistry {
        DexterIntegrationRegistry(
            healthMonitor: healthMonitor,
            customConfigurationStore: customConfigurationStore
        )
    }

    func refreshIntegrations(context: DexterIntegrationContext) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let connectors = makeRegistry().allConnectors()
        var refreshedIntegrations: [DexterIntegration] = []

        for connector in connectors {
            let snapshot = await connector.fetchSnapshot(context: context)
            refreshedIntegrations.append(
                DexterIntegration(
                    id: connector.integrationIdentifier,
                    name: connector.displayName,
                    kind: connector.integrationKind,
                    connectionState: snapshot.connectionState,
                    statusDetail: snapshot.statusDetail,
                    capabilities: snapshot.capabilities
                )
            )
        }

        integrations = refreshedIntegrations
    }

    func testCustomConnector(identifier: UUID) async -> DexterIntegrationSnapshot? {
        guard let configuration = customConfigurationStore.configuration(identifier: identifier) else {
            return nil
        }
        return await DexterCustomConnectorTester.testConnection(
            configuration: configuration,
            openClawHealthMonitor: healthMonitor
        )
    }

    func saveGitHubPersonalAccessToken(_ token: String) throws {
        try DexterGitHubConnector.savePersonalAccessToken(token)
    }

    func deleteGitHubPersonalAccessToken() throws {
        try DexterGitHubConnector.deletePersonalAccessToken()
    }

    func saveCustomConnectorAuthenticationSecret(
        connectorIdentifier: UUID,
        secret: String
    ) throws {
        let account = "custom-connector-\(connectorIdentifier.uuidString)"
        try DexterKeychainCredentialStore.saveUTF8Secret(secret, account: account)
    }

    func deleteCustomConnectorAuthenticationSecret(connectorIdentifier: UUID) throws {
        try DexterKeychainCredentialStore.deleteSecret(
            account: "custom-connector-\(connectorIdentifier.uuidString)"
        )
    }
}
