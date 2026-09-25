//
//  DexterProfileModels.swift
//  leanring-buddy
//
//  Product/workspace abstraction — not the Dexter macOS application itself.
//

import Foundation
import SwiftUI

enum DexterProfileMemoryScope: String, Codable, Equatable {
    /// Session and recalled context stay within this profile unless the user shares explicitly.
    case isolated
    case shared
}

struct DexterProfileAvatar: Codable, Equatable {
    var symbolName: String

    static let defaultSymbol = "sparkles"
}

struct DexterProfileWorkspace: Codable, Equatable {
    var folderPath: String?
    var label: String?

    static let empty = DexterProfileWorkspace(folderPath: nil, label: nil)
}

struct DexterProfilePermissions: Codable, Equatable {
    var allowsComputerActions: Bool
    var allowsIntegrations: Bool
    var allowsProactiveSuggestions: Bool

    static let defaultPermissions = DexterProfilePermissions(
        allowsComputerActions: true,
        allowsIntegrations: true,
        allowsProactiveSuggestions: true
    )
}

/// A specialized personal Dexter workspace (Study Buddy, Builder, …).
struct DexterProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var avatar: DexterProfileAvatar
    /// Hex color for accent chrome (e.g. #5CE1E6).
    var colorHex: String
    var purpose: String
    var memoryScope: DexterProfileMemoryScope
    var conversationID: UUID
    var workspace: DexterProfileWorkspace
    var connectedIntegrations: [String]
    var enabledSkills: [String]
    var workSuggestions: [DexterProfileWorkSuggestion]
    var permissions: DexterProfilePermissions
    var characterAppearance: DexterCharacterAppearance
    let createdAt: Date
    var updatedAt: Date

    var accentColor: Color {
        Color(hex: colorHex)
    }

    init(
        id: UUID,
        name: String,
        description: String,
        avatar: DexterProfileAvatar,
        colorHex: String,
        purpose: String,
        memoryScope: DexterProfileMemoryScope,
        conversationID: UUID,
        workspace: DexterProfileWorkspace,
        connectedIntegrations: [String],
        enabledSkills: [String],
        workSuggestions: [DexterProfileWorkSuggestion],
        permissions: DexterProfilePermissions,
        characterAppearance: DexterCharacterAppearance? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.avatar = avatar
        self.colorHex = colorHex
        self.purpose = purpose
        self.memoryScope = memoryScope
        self.conversationID = conversationID
        self.workspace = workspace
        self.connectedIntegrations = connectedIntegrations
        self.enabledSkills = enabledSkills
        self.workSuggestions = workSuggestions
        self.permissions = permissions
        if let characterAppearance {
            self.characterAppearance = characterAppearance
        } else {
            let characterID = DexterCharacterCatalog.defaultCharacterID(forProfileID: id)
            self.characterAppearance = DexterCharacterAppearance.defaultAppearance(forCharacterID: characterID)
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        avatar = try container.decode(DexterProfileAvatar.self, forKey: .avatar)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        purpose = try container.decode(String.self, forKey: .purpose)
        memoryScope = try container.decode(DexterProfileMemoryScope.self, forKey: .memoryScope)
        conversationID = try container.decode(UUID.self, forKey: .conversationID)
        workspace = try container.decode(DexterProfileWorkspace.self, forKey: .workspace)
        connectedIntegrations = try container.decode([String].self, forKey: .connectedIntegrations)
        enabledSkills = try container.decode([String].self, forKey: .enabledSkills)
        workSuggestions = try container.decodeIfPresent([DexterProfileWorkSuggestion].self, forKey: .workSuggestions) ?? []
        permissions = try container.decodeIfPresent(DexterProfilePermissions.self, forKey: .permissions) ?? .defaultPermissions
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        if let decodedAppearance = try container.decodeIfPresent(DexterCharacterAppearance.self, forKey: .characterAppearance) {
            characterAppearance = decodedAppearance
        } else {
            let characterID = DexterCharacterCatalog.defaultCharacterID(forProfileID: id)
            var migratedAppearance = DexterCharacterAppearance.defaultAppearance(forCharacterID: characterID)
            if let definition = DexterCharacterCatalog.character(withID: characterID) {
                migratedAppearance.background = definition.defaultAppearance.background
            }
            characterAppearance = migratedAppearance
        }
    }
}

enum DexterSeedProfileIdentifier {
    static let studyBuddy = UUID(uuidString: "A1000001-0001-4001-8001-000000000001")!
    static let builder = UUID(uuidString: "A1000002-0002-4002-8002-000000000002")!
    static let researcher = UUID(uuidString: "A1000003-0003-4003-8003-000000000003")!
    static let personal = UUID(uuidString: "A1000004-0004-4004-8004-000000000004")!
}

enum DexterHomeWorkspacePresentation: Equatable {
    case dashboard
    case dexterWorkspace(UUID)
}

