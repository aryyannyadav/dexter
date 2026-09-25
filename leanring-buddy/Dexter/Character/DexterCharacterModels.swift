//
//  DexterCharacterModels.swift
//  leanring-buddy
//

import Foundation
import SwiftUI

// MARK: - Customization capability (editor sections)

struct DexterCharacterCustomizationCapability: Codable, Equatable {
    var supportsHairStyles: Bool
    var supportsHairColors: Bool
    var supportsSkinTones: Bool
    var supportsEyes: Bool
    var supportsAccessories: Bool
    var supportsAvatarBackground: Bool

    static let backgroundOnly = DexterCharacterCustomizationCapability(
        supportsHairStyles: false,
        supportsHairColors: false,
        supportsSkinTones: false,
        supportsEyes: false,
        supportsAccessories: false,
        supportsAvatarBackground: true
    )

    static let fullModular = DexterCharacterCustomizationCapability(
        supportsHairStyles: true,
        supportsHairColors: true,
        supportsSkinTones: true,
        supportsEyes: true,
        supportsAccessories: true,
        supportsAvatarBackground: true
    )
}

// MARK: - Appearance (persisted per Dexter profile)

struct DexterCharacterAppearance: Codable, Equatable {
    var characterID: String
    var background: DexterCharacterBackgroundStyle
    var hairStyleID: String?
    var hairColorID: String?
    var skinToneID: String?
    var eyesID: String?
    var accessoryIDs: [String]

    static func defaultAppearance(forCharacterID characterID: String) -> DexterCharacterAppearance {
        DexterCharacterAppearance(
            characterID: characterID,
            background: .cream,
            hairStyleID: nil,
            hairColorID: nil,
            skinToneID: nil,
            eyesID: nil,
            accessoryIDs: []
        )
    }
}

enum DexterCharacterBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case cream
    case lavender
    case blush
    case sky
    case mint
    case peach

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .cream: return DexterPastelColors.cream
        case .lavender: return DexterPastelColors.lavender
        case .blush: return DexterPastelColors.blush
        case .sky: return DexterPastelColors.sky
        case .mint: return DexterPastelColors.mint
        case .peach: return DexterPastelColors.peach
        }
    }
}

// MARK: - Character definition (pack catalog entry)

struct DexterCharacterDefinition: Identifiable, Equatable, Codable {
    let id: String
    let packID: String
    let displayName: String
    let baseAssetName: String
    let previewAssetName: String
    let linkedProfileSeedID: UUID?
    let supportedOptions: DexterCharacterCustomizationCapability
    let defaultAppearance: DexterCharacterAppearance
}

struct DexterCharacterPack: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let description: String
    let thumbnailAssetName: String
    let characters: [DexterCharacterDefinition]
}
