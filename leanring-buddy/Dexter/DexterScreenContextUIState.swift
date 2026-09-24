//
//  DexterScreenContextUIState.swift
//  leanring-buddy
//

import Foundation

enum DexterScreenContextUIState: Equatable {
    case ready
    case permissionRequired
    case unavailable
    case analyzingScreen

    var userFacingLabel: String {
        switch self {
        case .ready:
            return "Screen context ready"
        case .permissionRequired:
            return "Screen recording permission required"
        case .unavailable:
            return "Context unavailable"
        case .analyzingScreen:
            return "Analyzing your screen…"
        }
    }
}
