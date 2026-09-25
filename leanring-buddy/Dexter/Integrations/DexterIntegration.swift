//
//  DexterIntegration.swift
//  leanring-buddy
//

import Foundation

struct DexterIntegration: Identifiable, Equatable {
    enum Kind: Equatable {
        case operational
        case discoveryReference
    }

    let id: String
    let name: String
    let kind: Kind
    let connectionState: DexterConnectionState
    let statusDetail: String?
    let capabilities: [DexterConnectorCapability]

    init(
        id: String,
        name: String,
        kind: Kind,
        connectionState: DexterConnectionState,
        statusDetail: String? = nil,
        capabilities: [DexterConnectorCapability] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.connectionState = connectionState
        self.statusDetail = statusDetail
        self.capabilities = capabilities
    }

    var subtitleLine: String {
        if let statusDetail, !statusDetail.isEmpty {
            return statusDetail
        }
        return connectionState.userFacingLabel
    }
}
