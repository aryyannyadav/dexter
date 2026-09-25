//
//  DexterSidebar.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSidebar: View {
    @ObservedObject var companionManager: CompanionManager
    var isCollapsed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identityHeader
                .padding(.horizontal, isCollapsed ? 10 : 16)
                .padding(.top, 18)
                .padding(.bottom, 16)

            if !isCollapsed {
                Button(action: { companionManager.startNewDexterConversation() }) {
                    Label("New chat", systemImage: "square.and.pencil")
                        .font(DexterIdentity.Typography.bodyMedium())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .padding(.horizontal, 12)
                .accessibilityLabel("New conversation")

                recentSection
                    .padding(.top, 16)

                Spacer()

                contextBlock
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                modelStatus
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            } else {
                Spacer()
            }

            Divider().background(DS.Colors.borderSubtle)

            sidebarFooter
                .padding(.horizontal, isCollapsed ? 8 : 12)
                .padding(.vertical, 12)
        }
        .frame(minWidth: isCollapsed ? 56 : 220, maxWidth: isCollapsed ? 56 : 260)
        .background(DS.Colors.surface1)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(DS.Colors.borderSubtle),
            alignment: .trailing
        )
    }

    private var identityHeader: some View {
        HStack(spacing: 10) {
            DexterMark(size: isCollapsed ? 22 : 28)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 2) {
                    Text(DexterProductCopy.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(DexterProductCopy.tagline)
                        .font(.system(size: 9))
                        .foregroundColor(DS.Colors.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)
                .padding(.horizontal, 16)

            if companionManager.dexterRecentConversations.isEmpty {
                Text("No recent chats")
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(companionManager.dexterRecentConversations.prefix(6)) { conversation in
                    Button {
                        companionManager.openRecentDexterConversation(conversation)
                    } label: {
                        Text(conversation.title)
                            .font(DexterIdentity.Typography.body())
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var contextBlock: some View {
        DexterContextIndicator(uiState: companionManager.dexterScreenContextUIState, compact: true)
    }

    private var modelStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DexterIdentity.accent.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(companionManager.selectedModelDisplayName)
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DS.Colors.textTertiary)
                .lineLimit(1)
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 4) {
            Button {
                NotificationCenter.default.post(name: .dexterOpenMainWindowSettings, object: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                        .frame(width: 18)
                    if !isCollapsed {
                        Text("Settings")
                            .font(DexterIdentity.Typography.bodyMedium())
                    }
                }
                .foregroundColor(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, isCollapsed ? 8 : 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("Settings")
        }
    }
}

/// Legacy alias — prefer `DexterLogo` in new UI.
struct DexterMark: View {
    var size: CGFloat = 24

    var body: some View {
        DexterLogo(size: size, style: .standard, animated: false)
            .accessibilityHidden(true)
    }
}
