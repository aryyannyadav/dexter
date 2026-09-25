//
//  DexterIntegrationRegistry.swift
//  leanring-buddy
//

import Foundation

@MainActor
final class DexterIntegrationRegistry {
    private let healthMonitor: OpenClawGatewayHealthMonitor
    private let customConfigurationStore: DexterCustomConnectorConfigurationStore

    init(
        healthMonitor: OpenClawGatewayHealthMonitor,
        customConfigurationStore: DexterCustomConnectorConfigurationStore = .shared
    ) {
        self.healthMonitor = healthMonitor
        self.customConfigurationStore = customConfigurationStore
    }

    func allConnectors() -> [DexterConnector] {
        var connectors: [DexterConnector] = operationalConnectors()

        let operationalNames = Set(connectors.map(\.displayName))
        let customNames = Set(customConfigurationStore.configurations.map(\.name))

        for referenceName in DexterIntegrationDiscoveryCatalog.referenceServiceNames {
            guard !operationalNames.contains(referenceName), !customNames.contains(referenceName) else {
                continue
            }
            let identifier = referenceName.lowercased().replacingOccurrences(of: " ", with: "-")
            connectors.append(
                DexterDiscoveryReferenceConnector(
                    integrationIdentifier: "discovery-\(identifier)",
                    displayName: referenceName
                )
            )
        }

        return connectors.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func connector(identifier: String) -> DexterConnector? {
        allConnectors().first { $0.integrationIdentifier == identifier }
    }

    private func operationalConnectors() -> [DexterConnector] {
        var connectors: [DexterConnector] = [
            DexterOpenClawGatewayConnector(healthMonitor: healthMonitor),
            DexterAmbientContextConnector(
                integrationIdentifier: "vscode",
                displayName: "Visual Studio Code",
                applicationNameMatchers: ["visual studio code", "code"],
                bundleIdentifierContains: "com.microsoft.vscode"
            ),
            DexterAmbientContextConnector(
                integrationIdentifier: "terminal",
                displayName: "Terminal",
                applicationNameMatchers: ["terminal", "iterm", "warp"],
                bundleIdentifierContains: "com.apple.terminal"
            ),
            DexterAmbientContextConnector(
                integrationIdentifier: "browser",
                displayName: "Browser",
                applicationNameMatchers: ["safari", "chrome", "firefox", "arc", "brave"],
                browserHostContains: nil
            ),
            DexterGitHubConnector()
        ]

        for configuration in customConfigurationStore.configurations {
            connectors.append(
                DexterCustomConnectorAdapter(configuration: configuration, healthMonitor: healthMonitor)
            )
        }

        return connectors
    }
}
