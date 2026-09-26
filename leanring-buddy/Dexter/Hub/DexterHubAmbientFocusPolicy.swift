//
//  DexterHubAmbientFocusPolicy.swift
//
//  Ambient focus when user has not enabled any proactive automations (Mac settings).
//

import Foundation

enum DexterHubAmbientFocusPolicy {
    static func isAmbientFocusMode(proactiveAutomationRegistrations: [DexterProactiveAutomationRegistration]) -> Bool {
        !proactiveAutomationRegistrations.contains(where: { $0.isExplicitlyEnabledByUser })
    }
}
