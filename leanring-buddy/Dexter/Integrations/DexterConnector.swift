//
//  DexterConnector.swift
//  leanring-buddy
//

import Foundation

struct DexterIntegrationContext: Equatable {
    let activeApplicationName: String?
    let browserPageURL: String?
    let browserPageTitle: String?
}

struct DexterIntegrationSnapshot: Equatable {
    let connectionState: DexterConnectionState
    let statusDetail: String?
    let capabilities: [DexterConnectorCapability]

    static let unsupported = DexterIntegrationSnapshot(
        connectionState: .unsupported,
        statusDetail: nil,
        capabilities: []
    )
}

protocol DexterConnector {
    var integrationIdentifier: String { get }
    var displayName: String { get }
    var integrationKind: DexterIntegration.Kind { get }

    func fetchSnapshot(context: DexterIntegrationContext) async -> DexterIntegrationSnapshot
}
