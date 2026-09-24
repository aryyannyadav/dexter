//
//  DexterModelGatewayRoute.swift
//  leanring-buddy
//

import Foundation

struct DexterModelGatewayRoute: Equatable {
    let backend: DexterModelBackendKind
    let modelIdentifier: String
    let requestedCapabilities: DexterModelCapabilitySet
    let routingReason: String
}

struct DexterModelGatewayRoutePlan: Equatable {
    let primaryRoute: DexterModelGatewayRoute
    let fallbackRoutes: [DexterModelGatewayRoute]

    var orderedRoutes: [DexterModelGatewayRoute] {
        [primaryRoute] + fallbackRoutes
    }
}
