//
//  DexterModelGatewayPreferences.swift
//  leanring-buddy
//

import Foundation

enum DexterModelGatewayPreferences {
    private static let prefersLocalProcessingKey = "DexterPrefersLocalModelProcessing"

    static var prefersLocalProcessing: Bool {
        UserDefaults.standard.bool(forKey: prefersLocalProcessingKey)
    }

    static func setPrefersLocalProcessing(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: prefersLocalProcessingKey)
    }
}
