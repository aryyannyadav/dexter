//
//  DexterSuggestionPresentationState.swift
//  leanring-buddy
//

import Combine
import Foundation

/// Shared presentation state for Home + future notch surfaces.
struct DexterSuggestionNotchPreview: Equatable {
    let suggestionItemId: String
    let title: String
    let dexterProfileId: UUID?
}

@MainActor
final class DexterSuggestionPresentationState: ObservableObject {
    @Published private(set) var homeSuggestions: [DexterHomeSuggestionItem] = []
    @Published private(set) var aggregatedSuggestions: [DexterHomeSuggestionItem] = []
    @Published private(set) var profileSuggestionsByProfileId: [UUID: [DexterHomeSuggestionItem]] = [:]
    @Published private(set) var presentationStatusByID: [String: DexterSuggestionPresentationStatus] = [:]
    @Published private(set) var notchPreview: DexterSuggestionNotchPreview?

    func updatePresentation(
        aggregated: [DexterHomeSuggestionItem],
        profileSuggestionsByProfileId: [UUID: [DexterHomeSuggestionItem]]
    ) {
        aggregatedSuggestions = aggregated
        self.profileSuggestionsByProfileId = profileSuggestionsByProfileId
        homeSuggestions = aggregated
        updateNotchPreview(from: aggregated)
    }

    func updateHomeSuggestions(_ suggestions: [DexterHomeSuggestionItem]) {
        updatePresentation(aggregated: suggestions, profileSuggestionsByProfileId: profileSuggestionsByProfileId)
    }

    func removeSuggestionFromPresentation(itemID: String) {
        aggregatedSuggestions = aggregatedSuggestions.filter { $0.id != itemID }
        homeSuggestions = aggregatedSuggestions
        var updatedByProfile = profileSuggestionsByProfileId
        for profileId in updatedByProfile.keys {
            updatedByProfile[profileId] = updatedByProfile[profileId]?.filter { $0.id != itemID }
        }
        profileSuggestionsByProfileId = updatedByProfile
        updateNotchPreview(from: aggregatedSuggestions)
    }

    func status(for suggestionID: String) -> DexterSuggestionPresentationStatus {
        presentationStatusByID[suggestionID] ?? .new
    }

    func setStatus(_ status: DexterSuggestionPresentationStatus, for suggestionID: String) {
        presentationStatusByID[suggestionID] = status
    }

    func clearStatus(for suggestionID: String) {
        presentationStatusByID.removeValue(forKey: suggestionID)
    }

    private func updateNotchPreview(from suggestions: [DexterHomeSuggestionItem]) {
        if let primary = suggestions.first {
            notchPreview = DexterSuggestionNotchPreview(
                suggestionItemId: primary.id,
                title: primary.title,
                dexterProfileId: primary.dexterProfileId
            )
        } else {
            notchPreview = nil
        }
    }
}
