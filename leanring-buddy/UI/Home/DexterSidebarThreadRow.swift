//
//  DexterSidebarThreadRow.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSidebarThreadRow: View {
    let item: DexterSidebarThreadItem
    let isSelected: Bool
    let relativeTimeText: String?
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: DexterSpacing.md) {
                leadingAvatar
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: DexterSpacing.sm) {
                        Text(item.title)
                            .font(DexterTypography.bodyMedium())
                            .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textSecondary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if let relativeTimeText {
                            Text(relativeTimeText)
                                .font(DexterTypography.metadata())
                                .foregroundColor(DexterColors.textTertiary)
                                .lineLimit(1)
                        }

                        if item.badgeCount > 0 {
                            Text("\(item.badgeCount)")
                                .font(DexterTypography.micro())
                                .foregroundColor(DexterColors.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DexterPastelColors.blush.opacity(0.55)))
                                .accessibilityLabel("\(item.badgeCount) unread")
                        }
                    }

                    Text(item.preview)
                        .font(DexterTypography.metadata())
                        .foregroundColor(isSelected ? DexterColors.textSecondary : DexterColors.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, DexterSpacing.md)
            .padding(.vertical, DexterSpacing.md)
            .background(selectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: DexterRadii.selectionSurface + 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .padding(.horizontal, DexterSpacing.xs)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(item.title). \(item.preview)")
    }

    @ViewBuilder
    private var leadingAvatar: some View {
        switch item.kind {
        case .suggestions:
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DexterPastelColors.blush, DexterPastelColors.lavender.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 48, height: 48)
        case .newChat:
            ZStack {
                Circle()
                    .fill(DexterSurfaceColors.surfaceElevated)
                Image(systemName: "plus.message.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DexterPastelColors.sky)
            }
            .frame(width: 48, height: 48)
        case .conversation, .profile:
            if let profile = item.profile {
                DexterAvatar(
                    profile: profile,
                    size: 48,
                    visualState: isSelected || isHovered ? .highlighted : .normal,
                    characterState: isSelected ? .listening : .idle,
                    animationEnabled: isSelected || isHovered
                )
            } else {
                ZStack {
                    Circle()
                        .fill(DexterSurfaceColors.surfaceElevated)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DexterPastelColors.sky)
                }
                .frame(width: 48, height: 48)
            }
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            ZStack {
                DexterPastelColors.selectionFill
                RoundedRectangle(cornerRadius: DexterRadii.selectionSurface + 2, style: .continuous)
                    .stroke(DexterPastelColors.sky.opacity(0.5), lineWidth: 1)
            }
            .shadow(color: DexterPastelColors.lavender.opacity(0.42), radius: 12, y: 0)
        } else if isHovered {
            RoundedRectangle(cornerRadius: DexterRadii.selectionSurface + 2, style: .continuous)
                .fill(Color.white.opacity(DexterInteractionOpacity.hover))
        } else {
            Color.clear
        }
    }
}
