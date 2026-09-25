//
//  DexterProfile+Sidebar.swift
//  leanring-buddy
//

import Foundation

extension DexterProfile {
    /// Short role line for profile sheets (full role editor comes in a later phase).
    var displayRole: String {
        let trimmedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPurpose.isEmpty { return trimmedPurpose }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDescription.isEmpty { return trimmedDescription }
        return "Workspace"
    }

    var lastActive: Date {
        updatedAt
    }
}

extension DexterProfile {
    func unreadConversationCount(in conversations: [DexterRecentConversationSummary]) -> Int {
        conversations.filter { $0.dexterProfileId == id && $0.isUnread }.count
    }
}
