//
//  DexterHomeSuggestionPresentationScope.swift
//  leanring-buddy
//

import Foundation

/// Which suggestion list a surface should read (all refreshed together from one store).
enum DexterHomeSuggestionPresentationScope: Equatable {
    case allDexters
    case dexterProfile(UUID)

    func resolvedSuggestions(from presentationState: DexterSuggestionPresentationState) -> [DexterHomeSuggestionItem] {
        switch self {
        case .allDexters:
            return presentationState.aggregatedSuggestions
        case .dexterProfile(let profileId):
            return presentationState.profileSuggestionsByProfileId[profileId] ?? []
        }
    }
}
