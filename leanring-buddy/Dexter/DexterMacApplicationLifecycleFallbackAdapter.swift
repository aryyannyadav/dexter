//
//  DexterMacApplicationLifecycleFallbackAdapter.swift
//  leanring-buddy
//
//  Explicit boundary for a future Mac-native lifecycle fallback. Not wired into CompositeDexter
//  automatically — OpenClaw advertised capabilities are required for launch/quit/focus/list.
//

import Foundation

protocol DexterApplicationLifecycleFallbackExecuting {
    func launchApplication(reference: DexterApplicationReference) async -> AgentActionResult?
    func quitApplication(reference: DexterApplicationReference) async -> AgentActionResult?
    func focusApplication(reference: DexterApplicationReference) async -> AgentActionResult?
}

/// Placeholder adapter for an opt-in, user-approved Mac fallback path (not used when OpenClaw lacks lifecycle actions).
enum DexterMacApplicationLifecycleFallbackAdapter: DexterApplicationLifecycleFallbackExecuting {
    static let notConfiguredMessage =
        "Application lifecycle fallback is not configured. Connect OpenClaw with launch_app, kill_app, bring_to_front, or list_apps."

    func launchApplication(reference: DexterApplicationReference) async -> AgentActionResult? {
        nil
    }

    func quitApplication(reference: DexterApplicationReference) async -> AgentActionResult? {
        nil
    }

    func focusApplication(reference: DexterApplicationReference) async -> AgentActionResult? {
        nil
    }
}
