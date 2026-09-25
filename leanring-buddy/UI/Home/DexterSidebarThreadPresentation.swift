//
//  DexterSidebarThreadPresentation.swift
//  leanring-buddy
//

import Foundation

/// View-only sidebar thread row (built from profiles, recents, and suggestions — no new stores).
struct DexterSidebarThreadItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case suggestions
        case newChat
        case conversation(UUID)
        case profile(UUID)
    }

    let id: String
    let kind: Kind
    let title: String
    let preview: String
    let timestamp: Date?
    let badgeCount: Int
    let profile: DexterProfile?

    static func build(
        companionManager: CompanionManager,
        searchState: DexterHomeSidebarSearchState
    ) -> [DexterSidebarThreadItem] {
        var threads: [DexterSidebarThreadItem] = []

        let suggestionPreview = companionManager.dexterSuggestionStore.presentationState.homeSuggestions.first?.title
            ?? "Ready when you are"
        let suggestionsThread = DexterSidebarThreadItem(
            id: "thread-suggestions",
            kind: .suggestions,
            title: "Suggestions",
            preview: suggestionPreview,
            timestamp: companionManager.dexterSuggestionStore.presentationState.homeSuggestions.first?.generatedAt,
            badgeCount: companionManager.dexterSuggestionStore.unreadSuggestionCount,
            profile: nil
        )
        if searchState.matches("Suggestions") || searchState.matches(suggestionPreview) {
            threads.append(suggestionsThread)
        }

        let newChatThread = DexterSidebarThreadItem(
            id: "thread-new-chat",
            kind: .newChat,
            title: "New chat",
            preview: "Start a fresh conversation",
            timestamp: nil,
            badgeCount: 0,
            profile: companionManager.dexterProfileStore.activeProfile
        )
        if searchState.matches("New chat") || searchState.matches("Start") {
            threads.append(newChatThread)
        }

        let recents = companionManager.dexterRecentConversations
        let profiles = companionManager.dexterProfileStore.profiles
        let profileById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        let conversationThreads: [DexterSidebarThreadItem] = recents
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(40)
            .compactMap { conversation in
                let profile = profileById[conversation.dexterProfileId]
                let preview = profile?.name ?? "Dexter"
                let thread = DexterSidebarThreadItem(
                    id: "thread-conversation-\(conversation.id.uuidString)",
                    kind: .conversation(conversation.id),
                    title: conversation.title,
                    preview: preview,
                    timestamp: conversation.lastUpdated,
                    badgeCount: conversation.isUnread ? 1 : 0,
                    profile: profile
                )
                guard searchState.matches(thread.title) || searchState.matches(thread.preview) else {
                    return nil
                }
                return thread
            }

        let profileIdsWithRecents = Set(recents.map(\.dexterProfileId))
        let dormantProfileThreads: [DexterSidebarThreadItem] = profiles
            .filter { !profileIdsWithRecents.contains($0.id) }
            .map { profile in
                DexterSidebarThreadItem(
                    id: "thread-profile-\(profile.id.uuidString)",
                    kind: .profile(profile.id),
                    title: profile.name,
                    preview: profile.displayRole,
                    timestamp: profile.lastActive,
                    badgeCount: 0,
                    profile: profile
                )
            }
            .filter { thread in
                searchState.matches(thread.title) || searchState.matches(thread.preview)
            }

        let activitySortedThreads = (conversationThreads + dormantProfileThreads)
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }

        threads.append(contentsOf: activitySortedThreads)
        return threads
    }
}
