//
//  DexterHomeSidebar.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeSidebar: View {
    @ObservedObject var companionManager: CompanionManager
    var selectedSection: DexterHomeSidebarSection
    var onSelectSection: (DexterHomeSidebarSection) -> Void
    var onCreateDexter: () -> Void
    var onEditCharacter: ((DexterProfile) -> Void)?
    var onOpenProfile: ((UUID) -> Void)?
    var isCompact: Bool = false

    @State private var searchState = DexterHomeSidebarSearchState()
    @State private var conversationPendingDeletion: UUID?
    @State private var conversationPendingRename: DexterRecentConversationSummary?
    @State private var renameDraftTitle: String = ""

    private static let relativeTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandHeader
                .padding(.horizontal, DexterSpacing.lg)
                .padding(.top, DexterSpacing.lg)
                .padding(.bottom, DexterSpacing.md)

            DexterSidebarSearchField(text: $searchState.query)
                .padding(.horizontal, DexterSpacing.md)
                .padding(.bottom, DexterSpacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: DexterSpacing.lg) {
                    suggestionsSection
                    dextersSection
                    recentSection
                }
                .padding(.bottom, DexterSpacing.md)
            }

            Spacer(minLength: DexterSpacing.sm)

            accountFooter
                .padding(.horizontal, DexterSpacing.lg)
                .padding(.bottom, DexterSpacing.sm)

            Divider()
                .background(DexterColors.borderSubtle)

            settingsButton
                .padding(.horizontal, DexterSpacing.sm)
                .padding(.vertical, DexterSpacing.md)
        }
        .frame(maxHeight: .infinity)
        .background(DexterSurfaceColors.secondaryBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DexterColors.borderSubtle)
                .frame(width: 1)
        }
        .alert("Delete this conversation?", isPresented: deleteConfirmationBinding) {
            Button("Delete", role: .destructive) {
                if let conversationId = conversationPendingDeletion {
                    companionManager.deleteRecentDexterConversation(conversationId: conversationId)
                }
                conversationPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                conversationPendingDeletion = nil
            }
        } message: {
            Text("This removes the conversation from Recent and deletes its saved messages.")
        }
        .sheet(item: $conversationPendingRename) { conversation in
            DexterConversationRenameSheet(
                initialTitle: conversation.title,
                onCancel: { conversationPendingRename = nil },
                onSave: { newTitle in
                    companionManager.renameRecentDexterConversation(
                        conversationId: conversation.id,
                        title: newTitle
                    )
                    conversationPendingRename = nil
                }
            )
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { conversationPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    conversationPendingDeletion = nil
                }
            }
        )
    }

    // MARK: - Sections

    @ViewBuilder
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.xs) {
            DexterSidebarSectionHeader(title: "SUGGESTIONS")
            DexterSidebarNavRow(
                title: "Suggestions",
                leadingSymbol: "sparkle",
                badgeCount: companionManager.dexterSuggestionStore.unreadSuggestionCount,
                isSelected: selectedSection == .suggestions,
                action: { onSelectSection(.suggestions) }
            )
            .padding(.horizontal, DexterSpacing.xs)

            DexterSidebarNavRow(
                title: "New chat",
                leadingSymbol: "square.and.pencil",
                isSelected: isNewChatSelected,
                action: {
                    onSelectSection(.chat)
                    companionManager.startNewDexterConversation()
                }
            )
            .padding(.horizontal, DexterSpacing.xs)
        }
    }

    @ViewBuilder
    private var dextersSection: some View {
        let profiles = filteredProfiles
        if !profiles.isEmpty {
            VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                DexterSidebarSectionHeader(title: "DEXTERS")
                ForEach(profiles) { profile in
                    DexterSidebarDexterRow(
                        profile: profile,
                        isSelected: isDexterProfileSelected(profileId: profile.id),
                        unreadCount: profile.unreadConversationCount(in: companionManager.dexterRecentConversations),
                        isCompact: isCompact,
                        action: {
                            onSelectSection(.chat)
                            companionManager.openDexterProfileWorkspace(profileId: profile.id)
                        },
                        onOpenProfile: onOpenProfile.map { openProfile in
                            { openProfile(profile.id) }
                        },
                        onEditCharacter: onEditCharacter.map { editCharacter in
                            { editCharacter(profile) }
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let recents = filteredRecentConversations
        VStack(alignment: .leading, spacing: DexterSpacing.xs) {
            DexterSidebarSectionHeader(title: "RECENT")
            if recents.isEmpty {
                Text(searchState.query.isEmpty ? "No conversations yet." : "No matching conversations.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textTertiary)
                    .padding(.horizontal, DexterSpacing.lg)
                    .padding(.vertical, DexterSpacing.sm)
            } else {
                ForEach(recents) { conversation in
                    let profile = companionManager.dexterProfileStore.profile(withId: conversation.dexterProfileId)
                    DexterSidebarRecentRow(
                        conversation: conversation,
                        profile: profile,
                        isSelected: companionManager.activeHomeConversationIdentifier == conversation.id,
                        relativeTimeText: relativeTimeLabel(for: conversation.lastUpdated),
                        isCompact: isCompact,
                        onOpen: {
                            onSelectSection(.chat)
                            companionManager.openRecentDexterConversation(conversation)
                        }
                    )
                    .contextMenu {
                        Button("Open") {
                            onSelectSection(.chat)
                            companionManager.openRecentDexterConversation(conversation)
                        }
                        Button("Rename") {
                            conversationPendingRename = conversation
                        }
                        Button("Mark as unread") {
                            companionManager.markRecentDexterConversationUnread(conversationId: conversation.id)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            conversationPendingDeletion = conversation.id
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filters

    private var filteredProfiles: [DexterProfile] {
        companionManager.dexterProfileStore.profiles.filter { profile in
            searchState.matches(profile.name) || searchState.matches(profile.displayRole)
        }
    }

    private var filteredRecentConversations: [DexterRecentConversationSummary] {
        companionManager.dexterRecentConversations
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .filter { conversation in
                searchState.matches(conversation.title)
                    || searchState.matches(
                        companionManager.dexterProfileStore.profile(withId: conversation.dexterProfileId)?.name ?? ""
                    )
            }
    }

    // MARK: - Chrome

    private var brandHeader: some View {
        HStack(spacing: DexterSpacing.md) {
            Button {
                onSelectSection(.chat)
                companionManager.openDexterHomeDashboard()
            } label: {
                HStack(spacing: DexterSpacing.sm) {
                    DexterLogo(size: isCompact ? 22 : 24, style: .glow, animated: false)
                    if !isCompact {
                        Text("DEXTER")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(DexterColors.textPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("Dexter home")

            Spacer(minLength: 0)

            Button(action: onCreateDexter) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DexterColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(DexterSurfaceColors.surface))
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("New Dexter")
        }
    }

    private var accountFooter: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.sm) {
            DexterContextIndicator(
                uiState: companionManager.dexterScreenContextUIState,
                compact: true
            )

            HStack(spacing: DexterSpacing.sm) {
                Circle()
                    .fill(DexterPastelColors.lavender.opacity(0.35))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(companionManager.dexterHomeUserFirstName.prefix(1).uppercased())
                            .font(DexterTypography.caption())
                            .foregroundColor(DexterColors.textPrimary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(companionManager.dexterHomeUserFirstName)
                        .font(DexterTypography.bodyMedium())
                        .foregroundColor(DexterColors.textPrimary)
                        .lineLimit(1)
                    Text(voiceStatusLabel)
                        .font(DexterTypography.metadata())
                        .foregroundColor(DexterColors.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func isDexterProfileSelected(profileId: UUID) -> Bool {
        if selectedSection == .suggestions { return false }
        if companionManager.activeHomeConversationIdentifier != nil { return false }
        if case .dexterWorkspace(let activeId) = companionManager.homeWorkspacePresentation {
            return activeId == profileId
        }
        return false
    }

    private func relativeTimeLabel(for date: Date) -> String {
        Self.relativeTimeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private var settingsButton: some View {
        DexterHomeSettingsNavButton()
    }

    private var isNewChatSelected: Bool {
        companionManager.activeHomeConversationIdentifier == nil
            && companionManager.dexterChatMessages.isEmpty
            && selectedSection == .chat
            && companionManager.homeWorkspacePresentation != .dashboard
    }

    private var voiceStatusLabel: String {
        switch companionManager.voiceInteractionState {
        case .listening: return "Listening"
        case .transcribing: return "Transcribing"
        case .thinking: return "Thinking"
        case .speaking: return "Speaking"
        case .error: return "Voice unavailable"
        case .idle: return companionManager.selectedModelDisplayName
        }
    }
}

private struct DexterConversationRenameSheet: View {
    let initialTitle: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var titleDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.lg) {
            Text("Rename conversation")
                .font(DexterTypography.sectionTitle())

            TextField("Title", text: $titleDraft)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave(titleDraft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DexterSpacing.xl)
        .frame(width: 360)
        .onAppear {
            titleDraft = initialTitle
        }
    }
}

private struct DexterHomeSettingsNavButton: View {
    @State private var isHovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .dexterOpenMainWindowSettings, object: nil)
        } label: {
            HStack(spacing: DexterSpacing.sm) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                Text("Settings")
                    .font(DexterTypography.bodyMedium())
            }
            .foregroundColor(isHovered ? DexterColors.textPrimary : DexterColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DexterSpacing.md)
            .padding(.vertical, DexterSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(DexterInteractionOpacity.hover) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel("Settings")
    }
}
