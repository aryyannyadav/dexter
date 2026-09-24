//
//  AIProvider.swift
//  leanring-buddy
//

import Foundation

enum AIProviderConnectionStatus: Equatable {
    case unknown
    case connected
    case notConnected
    case modelUnavailable

    var userFacingLabel: String {
        switch self {
        case .unknown:
            return "Checking…"
        case .connected:
            return "Connected"
        case .notConnected:
            return "Not connected"
        case .modelUnavailable:
            return "Model unavailable"
        }
    }
}

struct AIChatMessage: Equatable {
    let role: AIChatRole
    let content: String
    /// Base64-encoded image payloads (JPEG) for multimodal models such as Ollama vision.
    let base64Images: [String]

    init(role: AIChatRole, content: String, base64Images: [String] = []) {
        self.role = role
        self.content = content
        self.base64Images = base64Images
    }
}

enum AIChatRole: String, Codable {
    case system
    case user
    case assistant
}

/// Local/cloud-agnostic generation surface for Dexter chat and voice.
protocol AIProvider: AnyObject {
    var providerName: String { get }
    var endpointDisplayString: String { get }
    var configuredModelName: String { get }
    var connectionStatus: AIProviderConnectionStatus { get }

    func refreshConnectionStatus() async
    @discardableResult
    func testConnection() async -> AIProviderConnectionStatus

    func streamChat(
        messages: [AIChatMessage],
        resolvedModelName: String?,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> String
}
