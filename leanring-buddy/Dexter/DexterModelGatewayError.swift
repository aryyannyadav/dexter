//
//  DexterModelGatewayError.swift
//  leanring-buddy
//

import Foundation

enum DexterModelGatewayError: LocalizedError, Equatable {
    case noRouteAvailable
    case allBackendsFailed(lastErrorDescription: String)
    case backendNotConfigured(DexterModelBackendKind)

    var errorDescription: String? {
        switch self {
        case .noRouteAvailable:
            return "No model backend is available for this request."
        case .allBackendsFailed(let lastErrorDescription):
            return "All model backends failed. Last error: \(lastErrorDescription)"
        case .backendNotConfigured(let backend):
            return "\(backend.rawValue) is not configured for Dexter."
        }
    }
}
