//
//  DexterHomeSidebarComponents.swift
//  leanring-buddy
//

import SwiftUI

/// Sidebar search UI + local filter state (no backend search yet).
struct DexterHomeSidebarSearchState {
    var query: String = ""

    func matches(_ text: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(trimmed)
    }
}

struct DexterSidebarSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DexterSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isFocused ? DexterPastelColors.lavender : DexterColors.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textPrimary)
                .focused($isFocused)
        }
        .padding(.horizontal, DexterSpacing.md)
        .frame(height: DexterMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                .fill(DexterSurfaceColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                .stroke(isFocused ? DexterPastelColors.lavender.opacity(0.38) : DexterColors.border, lineWidth: 1)
        )
        .accessibilityLabel("Search sidebar")
    }
}

struct DexterSidebarSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: DexterSpacing.sm) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(DexterColors.textTertiary)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, DexterSpacing.lg)
    }
}

extension DexterSidebarSectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

struct DexterSidebarNavRow: View {
    let title: String
    var leadingSymbol: String
    var badgeCount: Int = 0
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DexterSpacing.sm) {
                Image(systemName: leadingSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(DexterTypography.bodyMedium())
                Spacer(minLength: 0)
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(DexterTypography.metadata())
                        .foregroundColor(DexterColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DexterColors.cardBackgroundElevated)
                        )
                        .accessibilityLabel("\(badgeCount) new")
                }
            }
            .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DexterSpacing.md)
            .padding(.vertical, DexterSpacing.sm + 4)
            .background(selectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: DexterRadii.selectionSurface, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            ZStack {
                DexterPastelColors.selectionFill
                RoundedRectangle(cornerRadius: DexterRadii.selectionSurface, style: .continuous)
                    .stroke(DexterPastelColors.sky.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: DexterPastelColors.lavender.opacity(0.35), radius: 10, y: 0)
        } else if isHovered {
            Color.white.opacity(DexterInteractionOpacity.hover)
        } else {
            Color.clear
        }
    }
}

struct DexterSidebarDexterRow: View {
    let profile: DexterProfile
    let isSelected: Bool
    var unreadCount: Int = 0
    var isCompact: Bool = false
    let action: () -> Void
    var onOpenProfile: (() -> Void)?
    var onEditCharacter: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: DexterSpacing.sm) {
            avatarControl

            Button(action: action) {
                HStack(alignment: .center, spacing: DexterSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(DexterTypography.bodyMedium())
                            .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textSecondary)
                            .lineLimit(1)
                        if !isCompact {
                            Text(profile.displayRole)
                                .font(DexterTypography.metadata())
                                .foregroundColor(DexterColors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(DexterTypography.metadata())
                            .foregroundColor(DexterColors.textOnAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(profile.accentColor.opacity(0.85)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("Open \(profile.name) conversation")
        }
        .padding(.horizontal, DexterSpacing.md)
        .padding(.vertical, DexterSpacing.sm + 2)
        .frame(minHeight: 52)
        .background(selectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: DexterRadii.selectionSurface, style: .continuous))
        .onHover { isHovered = $0 }
        .padding(.horizontal, DexterSpacing.xs)
        .contextMenu {
            Button("Open", action: action)
            if let onOpenProfile {
                Button("View profile", action: onOpenProfile)
                Button("Settings", action: onOpenProfile)
            }
            if let onEditCharacter {
                Button("Edit character", action: onEditCharacter)
                Button("Edit", action: onEditCharacter)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var avatarControl: some View {
        let avatar = DexterCharacterImage(
            profile: profile,
            characterState: isSelected ? .listening : .idle,
            size: isCompact ? 40 : 44,
            animationEnabled: isSelected || isHovered,
            isHovered: isHovered
        )

        if let onOpenProfile {
            Button(action: onOpenProfile) {
                avatar
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("\(profile.name) profile")
        } else {
            avatar
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            ZStack {
                DexterPastelColors.selectionFill
                RoundedRectangle(cornerRadius: DexterRadii.selectionSurface, style: .continuous)
                    .stroke(DexterPastelColors.sky.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: DexterPastelColors.lavender.opacity(0.35), radius: 10, y: 0)
        } else if isHovered {
            Color.white.opacity(DexterInteractionOpacity.hover)
        } else {
            Color.clear
        }
    }
}

struct DexterSidebarRecentRow: View {
    let conversation: DexterRecentConversationSummary
    let profile: DexterProfile?
    let isSelected: Bool
    let relativeTimeText: String
    var isCompact: Bool
    let onOpen: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: DexterSpacing.sm) {
                if let profile {
                    DexterAvatar(
                        profile: profile,
                        size: DexterAvatarSize.sm,
                        visualState: isSelected ? .highlighted : .normal,
                        characterState: .idle,
                        animationEnabled: false
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textSecondary)
                        .lineLimit(isCompact ? 1 : 2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: DexterSpacing.sm) {
                        Text(profile?.name ?? "Dexter")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(DexterColors.textTertiary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(relativeTimeText)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(DexterColors.textMuted)
                            .lineLimit(1)
                    }
                }

                if conversation.isUnread {
                    DexterStatusDot(tone: .active, showsSoftGlow: false)
                }
            }
            .padding(.horizontal, DexterSpacing.md)
            .padding(.vertical, DexterSpacing.sm + 4)
            .frame(minHeight: 48)
            .background(selectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: DexterRadii.selectionSurface, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .padding(.horizontal, DexterSpacing.xs)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            DexterPastelColors.selectionFill
        } else if isHovered {
            Color.white.opacity(DexterInteractionOpacity.hover)
        } else {
            Color.clear
        }
    }
}
