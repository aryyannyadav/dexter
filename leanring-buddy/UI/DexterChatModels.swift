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
    var title: String
    var lastUpdated: Date
    var isUnread: Bool
    var dexterProfileId: UUID

    init(
        id: UUID,
        title: String,
        lastUpdated: Date,
        isUnread: Bool = false,
        dexterProfileId: UUID = DexterSeedProfileIdentifier.personal
    ) {
        self.id = id
        self.title = title
        self.lastUpdated = lastUpdated
        self.isUnread = isUnread
        self.dexterProfileId = dexterProfileId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        isUnread = try container.decodeIfPresent(Bool.self, forKey: .isUnread) ?? false
        dexterProfileId = try container.decodeIfPresent(UUID.self, forKey: .dexterProfileId)
            ?? DexterSeedProfileIdentifier.personal
    }
}

enum DexterMainWindowDestination: Equatable {
    case chat
    case settings
}

enum DexterProductCopy {
    static let name = "DEXTER"
    static let tagline = "Your computer finally understands you."
}
