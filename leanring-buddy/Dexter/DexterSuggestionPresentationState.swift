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
    @Published private(set) var presentationStatusByID: [String: DexterSuggestionPresentationStatus] = [:]
    @Published private(set) var notchPreview: DexterSuggestionNotchPreview?

    func updateHomeSuggestions(_ suggestions: [DexterHomeSuggestionItem]) {
        homeSuggestions = suggestions
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

    func status(for suggestionID: String) -> DexterSuggestionPresentationStatus {
        presentationStatusByID[suggestionID] ?? .new
    }

    func setStatus(_ status: DexterSuggestionPresentationStatus, for suggestionID: String) {
        presentationStatusByID[suggestionID] = status
    }

    func clearStatus(for suggestionID: String) {
        presentationStatusByID.removeValue(forKey: suggestionID)
    }
}
