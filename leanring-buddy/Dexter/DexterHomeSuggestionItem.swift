//
//  DexterHomeSuggestionItem.swift
//  leanring-buddy
//

import Foundation

/// Unified home/notch presentation over context + profile-work suggestions.
enum DexterHomeSuggestionItem: Identifiable, Equatable {
    case context(DexterSuggestion)
    case profileWork(DexterProfileWorkSuggestion)

    var id: String {
        switch self {
        case .context(let suggestion):
            return suggestion.id
        case .profileWork(let suggestion):
            return suggestion.persistenceIdentifier
        }
    }

    var dexterProfileId: UUID? {
        switch self {
        case .context(let suggestion):
            return suggestion.dexterProfileId
        case .profileWork(let suggestion):
            return suggestion.dexterProfileId
        }
    }

    var title: String {
        switch self {
        case .context(let suggestion):
            return suggestion.title
        case .profileWork(let suggestion):
            return suggestion.headline
        }
    }

    var subtitle: String {
        switch self {
        case .context(let suggestion):
            return suggestion.subtitle
        case .profileWork(let suggestion):
            return suggestion.body
        }
    }

    var sourceLabel: String {
        switch self {
        case .context(let suggestion):
            return suggestion.source.displayLabel
        case .profileWork(let suggestion):
            return suggestion.source.displayDetail
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .context(let suggestion):
            return suggestion.primaryActionTitle
        case .profileWork(let suggestion):
            return suggestion.primaryActionTitle
        }
    }

    var accentIndex: Int {
        switch self {
        case .context(let suggestion):
            return suggestion.accentIndex
        case .profileWork:
            return 0
        }
    }

    var priority: Int {
        switch self {
        case .context(let suggestion):
            return suggestion.priority
        case .profileWork(let suggestion):
            return suggestion.priority
        }
    }

    var isUnread: Bool {
        switch self {
        case .context(let suggestion):
            return suggestion.isUnread
        case .profileWork(let suggestion):
            return suggestion.isUnread
        }
    }

    /// When the suggestion was grounded or refreshed (sidebar thread timestamps).
    var generatedAt: Date {
        switch self {
        case .context(let suggestion):
            return suggestion.groundedAt
        case .profileWork(let suggestion):
            return suggestion.refreshedAt
        }
    }
}
