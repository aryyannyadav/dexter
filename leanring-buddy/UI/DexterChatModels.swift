//
//  DexterChatModels.swift
//  leanring-buddy
//

import Foundation

struct DexterChatMessage: Identifiable, Equatable, Codable {
    enum Role: String, Equatable, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date
    var isError: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        timestamp: Date = Date(),
        isError: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.isError = isError
    }
}

struct DexterRecentConversationSummary: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let lastUpdated: Date
}

enum DexterMainWindowDestination: Equatable {
    case chat
    case settings
}

enum DexterProductCopy {
    static let name = "DEXTER"
    static let tagline = "Your computer finally understands you."
}
