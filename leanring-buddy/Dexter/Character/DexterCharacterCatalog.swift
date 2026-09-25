//
//  DexterCharacterCatalog.swift
//  leanring-buddy
//

import Foundation

enum DexterCharacterCatalog {
    static let corePackID = "dexter-core"

    static let studyBuddyCharacterID = "study-buddy"
    static let builderCharacterID = "builder"
    static let researcherCharacterID = "researcher"
    static let personalCharacterID = "personal"

    static var corePack: DexterCharacterPack {
        DexterCharacterPack(
            id: corePackID,
            name: "Dexter Core",
            description: "Foundational Dexter companions for study, building, research, and personal work.",
            thumbnailAssetName: "dexter_character_study_buddy",
            characters: coreCharacters
        )
    }

    static var coreCharacters: [DexterCharacterDefinition] {
        [
            definition(
                id: studyBuddyCharacterID,
                displayName: "Study Buddy",
                baseAsset: "dexter_character_study_buddy",
                profileSeed: DexterSeedProfileIdentifier.studyBuddy,
                background: .lavender
            ),
            definition(
                id: builderCharacterID,
                displayName: "Builder",
                baseAsset: "dexter_character_builder",
                profileSeed: DexterSeedProfileIdentifier.builder,
                background: .sky
            ),
            definition(
                id: researcherCharacterID,
                displayName: "Researcher",
                baseAsset: "dexter_character_researcher",
                profileSeed: DexterSeedProfileIdentifier.researcher,
                background: .peach
            ),
            definition(
                id: personalCharacterID,
                displayName: "Personal",
                baseAsset: "dexter_character_personal",
                profileSeed: DexterSeedProfileIdentifier.personal,
                background: .mint
            )
        ]
    }

    static func character(withID characterID: String) -> DexterCharacterDefinition? {
        coreCharacters.first { $0.id == characterID }
    }

    static func defaultCharacterID(forProfileID profileID: UUID) -> String {
        switch profileID {
        case DexterSeedProfileIdentifier.studyBuddy: return studyBuddyCharacterID
        case DexterSeedProfileIdentifier.builder: return builderCharacterID
        case DexterSeedProfileIdentifier.researcher: return researcherCharacterID
        case DexterSeedProfileIdentifier.personal: return personalCharacterID
        default: return personalCharacterID
        }
    }

    static func defaultAppearance(forProfile profile: DexterProfile) -> DexterCharacterAppearance {
        let characterID = defaultCharacterID(forProfileID: profile.id)
        var appearance = DexterCharacterAppearance.defaultAppearance(forCharacterID: characterID)
        if let definition = character(withID: characterID) {
            appearance.background = definition.defaultAppearance.background
        }
        return appearance
    }

    private static func definition(
        id: String,
        displayName: String,
        baseAsset: String,
        profileSeed: UUID,
        background: DexterCharacterBackgroundStyle
    ) -> DexterCharacterDefinition {
        let defaultAppearance = DexterCharacterAppearance(
            characterID: id,
            background: background,
            hairStyleID: nil,
            hairColorID: nil,
            skinToneID: nil,
            eyesID: nil,
            accessoryIDs: []
        )
        return DexterCharacterDefinition(
            id: id,
            packID: corePackID,
            displayName: displayName,
            baseAssetName: baseAsset,
            previewAssetName: baseAsset,
            linkedProfileSeedID: profileSeed,
            supportedOptions: .backgroundOnly,
            defaultAppearance: defaultAppearance
        )
    }
}
