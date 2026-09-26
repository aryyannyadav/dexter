//
//  DexterSuggestionCard.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSuggestionCard: View {
    let item: DexterHomeSuggestionItem
    let profile: DexterProfile?
    let status: DexterSuggestionPresentationStatus
    var isPrimary: Bool = true
    var usesHeroPresentation: Bool = false
    var showsLeadingCharacter: Bool = true
    var staggerIndex: Int = 0
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    let onAdjust: ((DexterSuggestionAdjustOption) -> Void)?
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isExiting = false
    @State private var showsAcceptFlash = false

    private var displayedCharacterState: DexterCharacterState {
        if showsAcceptFlash || status == .completed {
            return .success
        }
        return characterStateForCard
    }

    var body: some View {
        cardContent
            .scaleEffect(cardScale, anchor: .center)
            .opacity(isExiting ? 0 : 1)
            .offset(x: isExiting ? 14 : 0, y: isExiting ? 6 : (isHovered && !DexterMotionPreferences.shouldReduceMotion ? -2 : 0))
            .animation(DexterSuggestionMotion.hoverEase, value: isHovered)
            .animation(DexterSuggestionMotion.exitEase, value: isExiting)
            .dexterSuggestionCardEntrance(staggerIndex: staggerIndex)
            .onHover { isHovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Suggestion: \(item.title). \(item.subtitle)")
    }

    private var cardScale: CGFloat {
        if isExiting { return 0.98 }
        if isPressed { return 0.985 }
        return 1
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            HStack(alignment: .center, spacing: 14) {
                DexterSuggestionLeadingCharacter(
                    profile: profile,
                    characterState: displayedCharacterState,
                    showsCharacter: showsLeadingCharacter,
                    isHovered: isHovered,
                    animationEnabled: isHovered || status == .running || showsAcceptFlash,
                    staggerIndex: staggerIndex
                )

                VStack(alignment: .leading, spacing: 4) {
                    if !usesHeroPresentation {
                        HStack {
                            Text(DexterHomeSuggestionDisplayPlanner.categoryLabel(for: item).uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.35)
                                .foregroundColor(categoryTint.opacity(0.95))
                            Spacer(minLength: 0)
                            Button(action: performDismiss) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(DexterSurfaceColors.textMuted)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                            .accessibilityLabel("Dismiss suggestion")
                        }
                    }

                    Text(item.title)
                        .font(.system(size: usesHeroPresentation ? 17 : 16, weight: .semibold))
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let personaLabel = personaLabelText {
                        Text(personaLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(categoryTint.opacity(0.92))
                    }

                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(DexterSurfaceColors.textSecondary)
                        .lineLimit(usesHeroPresentation ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            actionRow
        }
        .padding(usesHeroPresentation ? DexterSpacing.lg + 4 : DexterSpacing.lg)
        .frame(minHeight: 150, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dexterCardSurface(
            accentColor: categoryTint,
            isHovered: isHovered && !isExiting,
            cornerRadius: DexterRadii.card
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DexterPastelColors.suggestionSurface(for: item.accentIndex).opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)
        )
    }

    private var categoryTint: Color {
        profile?.accentColor ?? DexterPastelColors.suggestionSurface(for: item.accentIndex)
    }

    private var personaLabelText: String? {
        if let profile {
            return profile.name
        }
        if let name = DexterHomeSuggestionDisplayPlanner.personaDisplayName(for: item) {
            return name
        }
        return nil
    }

    private var characterStateForCard: DexterCharacterState {
        switch status {
        case .running: return .working
        case .completed: return .success
        case .failed: return .error
        case .new, .dismissed:
            break
        }
        switch item {
        case .context(let suggestion):
            if suggestion.outcome == .teaching || suggestion.kind == .explainError {
                return .thinking
            }
            if suggestion.outcome == .action || suggestion.outcome == .agentTask {
                return .working
            }
            return .idle
        case .profileWork(let workSuggestion):
            switch workSuggestion.category {
            case .research, .explain:
                return .thinking
            case .task, .integration:
                return .working
            case .continueWork, .pickUpWhereYouLeftOff:
                return .idle
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch status {
        case .running:
            HStack(spacing: DexterSpacing.sm) {
                ProgressView().controlSize(.small)
                Text("Working…")
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
            }
        case .completed:
            HStack(spacing: DexterSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DexterSurfaceColors.success)
                Text("Done")
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
            }
        case .failed:
            HStack(spacing: DexterSpacing.sm) {
                Text("That didn't work.")
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.warning)
                Button("Try again", action: onRetry)
                    .buttonStyle(.plain)
                    .font(DexterTypography.metadata())
                    .foregroundColor(profile?.accentColor ?? DexterSurfaceColors.accent)
                    .pointerCursor()
            }
        default:
            if usesHeroPresentation {
                DexterSuggestionHeroActionPills(
                    primaryTitle: item.primaryActionTitle,
                    adjustOptions: adjustOptions ?? [],
                    onDismiss: performDismiss,
                    onPrimary: performAccept,
                    onAdjust: onAdjust
                )
                .padding(.top, DexterSpacing.xs)
            } else {
                compactActionRow
            }
        }
    }

    private var compactActionRow: some View {
        HStack(spacing: DexterSpacing.sm) {
            Button(action: performAccept) {
                Text(item.primaryActionTitle)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .padding(.horizontal, DexterSpacing.md)
                    .padding(.vertical, DexterSpacing.sm)
                    .background(
                        Capsule()
                            .fill(categoryTint.opacity(0.22))
                    )
            }
            .buttonStyle(DexterSuggestionPillButtonStyle())
            .pointerCursor()

            if let onSecondaryAction, let secondaryTitle = secondaryActionTitle {
                Button(secondaryTitle, action: onSecondaryAction)
                    .buttonStyle(DexterSuggestionPillButtonStyle())
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textMuted)
                    .pointerCursor()
            }
        }
    }

    private var adjustOptions: [DexterSuggestionAdjustOption]? {
        if case .context(let suggestion) = item {
            return suggestion.adjustOptions
        }
        return nil
    }

    private var secondaryActionTitle: String? {
        if case .context(let suggestion) = item {
            return suggestion.secondaryActionTitle
        }
        return "Dismiss"
    }

    private func performAccept() {
        guard !isExiting else { return }
        if DexterMotionPreferences.shouldReduceMotion {
            onPrimaryAction()
            return
        }
        showsAcceptFlash = true
        withAnimation(DexterSuggestionMotion.exitEase) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            onPrimaryAction()
        }
    }

    private func performDismiss() {
        guard !isExiting else { return }
        if DexterMotionPreferences.shouldReduceMotion {
            onDismiss()
            return
        }
        withAnimation(DexterSuggestionMotion.exitEase) {
            isExiting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            onDismiss()
        }
    }
}

struct DexterSuggestionPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : (configuration.isPressed ? 0 : 0))
            .animation(
                DexterMotionPreferences.shouldReduceMotion
                    ? nil
                    : .easeOut(duration: 0.14),
                value: configuration.isPressed
            )
    }
}
