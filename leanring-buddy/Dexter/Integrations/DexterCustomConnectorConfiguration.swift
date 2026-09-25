//
//  DexterCustomConnectorConfiguration.swift
//  leanring-buddy
//

import Combine
import Foundation

enum DexterCustomConnectorKind: String, Codable, CaseIterable, Identifiable {
    case mcp
    case openClaw

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mcp: return "MCP server"
        case .openClaw: return "OpenClaw node"
        }
    }
}

enum DexterCustomConnectorTransport: String, Codable, Equatable {
    case remoteServerURL
    case localCommand
}

struct DexterCustomConnectorConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: DexterCustomConnectorKind
    var transport: DexterCustomConnectorTransport
    var serverURLString: String
    var localCommand: String

    init(
        id: UUID = UUID(),
        name: String,
        kind: DexterCustomConnectorKind,
        transport: DexterCustomConnectorTransport,
        serverURLString: String = "",
        localCommand: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.transport = transport
        self.serverURLString = serverURLString
        self.localCommand = localCommand
    }

    var keychainAccount: String {
        "custom-connector-\(id.uuidString)"
    }
}

@MainActor
final class DexterCustomConnectorConfigurationStore: ObservableObject {
    static let shared = DexterCustomConnectorConfigurationStore()

    @Published private(set) var configurations: [DexterCustomConnectorConfiguration] = []

    private let storageKey = "dexterCustomConnectorConfigurationsJSON"
    private let legacyStorageKey = "dexterCustomConnectorsJSON"

    private init() {
        loadFromDisk()
    }

    func addConfiguration(_ configuration: DexterCustomConnectorConfiguration) {
        configurations.append(configuration)
        persistToDisk()
    }

    func updateConfiguration(_ configuration: DexterCustomConnectorConfiguration) {
        guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else { return }
        configurations[index] = configuration
        persistToDisk()
    }

    func removeConfiguration(identifier: UUID) {
        configurations.removeAll { $0.id == identifier }
        try? DexterKeychainCredentialStore.deleteSecret(account: "custom-connector-\(identifier.uuidString)")
        persistToDisk()
    }

    func configuration(identifier: UUID) -> DexterCustomConnectorConfiguration? {
        configurations.first { $0.id == identifier }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DexterCustomConnectorConfiguration].self, from: data) {
            configurations = decoded
            return
        }

        migrateLegacyConnectorsIfNeeded()
    }

    private func migrateLegacyConnectorsIfNeeded() {
        guard let legacyData = UserDefaults.standard.data(forKey: legacyStorageKey),
              let legacyConnectors = try? JSONDecoder().decode([LegacyCustomConnector].self, from: legacyData) else {
            configurations = []
            return
        }

        configurations = legacyConnectors.map { legacy in
            let transport: DexterCustomConnectorTransport
            let trimmedEndpoint = legacy.endpointDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedEndpoint.contains("://") || trimmedEndpoint.hasPrefix("http") {
                transport = .remoteServerURL
            } else if trimmedEndpoint.isEmpty {
                transport = .remoteServerURL
            } else {
                transport = .localCommand
            }

            return DexterCustomConnectorConfiguration(
                id: legacy.id,
                name: legacy.name,
                kind: legacy.kind,
                transport: transport,
                serverURLString: transport == .remoteServerURL ? trimmedEndpoint : "",
                localCommand: transport == .localCommand ? trimmedEndpoint : ""
            )
        }

        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        persistToDisk()
    }

    private func persistToDisk() {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private struct LegacyCustomConnector: Codable {
        let id: UUID
        let name: String
        let kind: DexterCustomConnectorKind
        let endpointDescription: String
    }
}
