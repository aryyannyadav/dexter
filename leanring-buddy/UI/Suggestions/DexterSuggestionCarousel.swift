//
//  DexterSuggestionCarousel.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSuggestionCarousel: View {
    enum Layout {
        case compact
        case centerStage
    }

    @ObservedObject var companionManager: CompanionManager
    let items: [DexterHomeSuggestionItem]
    var layout: Layout = .compact

    @State private var scrollPositionID: String?

    var body: some View {
        VStack(alignment: layout == .centerStage ? .center : .leading, spacing: DexterSpacing.md) {
            if items.count > 1 {
                paginationHeader
            }

            if layout == .centerStage {
                centerStageSuggestionDeck
            } else {
                compactHorizontalCarousel
            }

            if items.count > 1, layout == .compact {
                paginationDots
            }
        }
        .onAppear {
            scrollPositionID = items.first?.id
        }
    }

    private var compactHorizontalCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DexterSpacing.lg) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    suggestionCard(for: item, index: index, usesHero: false)
                        .frame(width: cardWidth)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPositionID)
    }

    private var centerStageSuggestionDeck: some View {
        let activeIndex = max(0, items.firstIndex(where: { $0.id == scrollPositionID }) ?? 0)

        return ZStack(alignment: .top) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let depth = index - activeIndex
                if depth > 0 && depth <= 2 {
                    suggestionCard(for: item, index: index, usesHero: false)
                        .frame(width: cardWidth * (1 - CGFloat(depth) * 0.04))
                        .scaleEffect(1 - CGFloat(depth) * 0.035)
                        .offset(y: CGFloat(depth) * 14)
                        .opacity(0.42 - CGFloat(depth - 1) * 0.08)
                        .allowsHitTesting(false)
                        .zIndex(Double(-depth))
                }
            }

            if let activeItem = items[safe: activeIndex] {
                suggestionCard(for: activeItem, index: activeIndex, usesHero: true)
                    .frame(width: cardWidth)
                    .id(activeItem.id)
                    .zIndex(10)
            }
        }
        .frame(maxWidth: cardWidth)
        .padding(.top, items.count > 1 ? DexterSpacing.lg : 0)
        .padding(.bottom, items.count > 1 ? DexterSpacing.md : 0)
    }

    private func suggestionCard(for item: DexterHomeSuggestionItem, index: Int, usesHero: Bool) -> some View {
        DexterSuggestionCard(
            item: item,
            profile: profile(for: item),
            status: companionManager.dexterSuggestionStore.presentationState.status(for: item.id),
            isPrimary: index == 0,
            usesHeroPresentation: usesHero,
            onPrimaryAction: { accept(item) },
            onSecondaryAction: { companionManager.dexterSuggestionStore.dismissHomeSuggestion(item) },
            onAdjust: { option in
                companionManager.dexterSuggestionStore.acceptHomeSuggestion(
                    item,
                    userPromptOverride: option.userPrompt
                )
                focusChat()
            },
            onDismiss: { companionManager.dexterSuggestionStore.dismissHomeSuggestion(item) },
            onRetry: { companionManager.dexterSuggestionStore.retryHomeSuggestion(item) }
        )
    }

    private var cardWidth: CGFloat {
        switch layout {
        case .centerStage:
            return min(520, DexterConversationLayout.chatColumnMaxWidth)
        case .compact:
            return min(380, DexterConversationLayout.chatColumnMaxWidth)
        }
    }

    private var paginationHeader: some View {
        let currentIndex = max(0, items.firstIndex(where: { $0.id == scrollPositionID }) ?? 0)
        return HStack(spacing: DexterSpacing.md) {
            if layout == .centerStage {
                Button {
                    scrollToPrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DexterSurfaceColors.surface))
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

            Text("\(currentIndex + 1) of \(items.count)")
                .font(DexterTypography.metadata())
                .foregroundColor(DexterSurfaceColors.textMuted)

            if layout == .centerStage {
                Button {
                    scrollToNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DexterSurfaceColors.surface))
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .frame(maxWidth: .infinity, alignment: layout == .centerStage ? .center : .leading)
    }

    private var paginationDots: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Circle()
                    .fill(item.id == scrollPositionID ? DexterSurfaceColors.textSecondary : DexterSurfaceColors.textMuted.opacity(0.35))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.top, 2)
    }

    private func scrollToPrevious() {
        guard let currentID = scrollPositionID,
              let index = items.firstIndex(where: { $0.id == currentID }),
              index > 0 else { return }
        scrollPositionID = items[index - 1].id
    }

    private func scrollToNext() {
        guard let currentID = scrollPositionID,
              let index = items.firstIndex(where: { $0.id == currentID }),
              index < items.count - 1 else { return }
        scrollPositionID = items[index + 1].id
    }

    private func profile(for item: DexterHomeSuggestionItem) -> DexterProfile? {
        guard let profileId = item.dexterProfileId else {
            return companionManager.dexterProfileStore.activeProfile
        }
        return companionManager.dexterProfileStore.profile(withId: profileId)
    }

    private func accept(_ item: DexterHomeSuggestionItem) {
        companionManager.dexterSuggestionStore.acceptHomeSuggestion(item)
        focusChat()
    }

    private func focusChat() {
        NotificationCenter.default.post(name: .dexterHomeFocusChat, object: nil)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
