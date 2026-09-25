//
//  DexterConnectionState.swift
//  leanring-buddy
//

import Foundation

enum DexterConnectionState: Equatable {
    case notConnected
    case connecting
    case connected
    case needsAuthentication
    case error(message: String)
    case unsupported

    var userFacingLabel: String {
        switch self {
        case .notConnected:
            return "Not connected"
        case .connecting:
            return "Connecting…"
        case .connected:
            return "Connected"
        case .needsAuthentication:
            return "Needs sign in"
        case .error:
            return "Error"
        case .unsupported:
            return "Not available yet"
        }
    }
}
