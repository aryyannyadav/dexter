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
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    let onAdjust: ((DexterSuggestionAdjustOption) -> Void)?
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Group {
            if usesHeroPresentation {
                heroCard
            } else {
                compactCard
            }
        }
        .scaleEffect(isPressed ? 0.985 : (isHovered ? 1.01 : 1))
        .animation(DexterAnimation.fastSpring, value: isHovered)
        .animation(DexterAnimation.fastSpring, value: isPressed)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggestion: \(item.title). \(item.subtitle)")
    }

    private var heroCard: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DexterSpacing.md) {
                Color.clear.frame(height: 36)

                Text(item.sourceLabel.uppercased())
                    .font(DexterTypography.micro())
                    .foregroundColor(DexterColors.textTertiary)

                Text(item.title)
                    .font(DexterTypography.cardTitle())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.subtitle)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                actionRow
            }
            .padding(DexterSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(heroCardBackground)
            .overlay(heroCardBorder)
            .shadow(color: Color.black.opacity(isHovered ? 0.2 : 0.12), radius: isHovered ? 16 : 10, y: 6)

            if let profile {
                DexterCharacterStagePortrait(
                    profile: profile,
                    characterState: characterStateForCard,
                    height: 88,
                    animationEnabled: isHovered || status == .running
                )
                .offset(y: -44)
                .allowsHitTesting(false)
            }
        }
    }

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            HStack(alignment: .top, spacing: DexterSpacing.sm) {
                compactCharacterView
                    .offset(y: -4)

                VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                    Text(item.title)
                        .font(isPrimary ? DexterTypography.bodyMedium() : DexterTypography.messageCompact())
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.subtitle)
                        .font(DexterTypography.metadata())
                        .foregroundColor(DexterSurfaceColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(DexterSurfaceColors.textMuted)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .accessibilityLabel("Dismiss suggestion")
            }

            actionRow
        }
        .padding(DexterSpacing.lg)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: Color.black.opacity(isHovered ? 0.14 : 0.06), radius: isHovered ? 10 : 6, y: 3)
    }

    @ViewBuilder
    private var compactCharacterView: some View {
        if let profile {
            DexterCharacterStagePortrait(
                profile: profile,
                characterState: characterStateForCard,
                height: 48,
                animationEnabled: status == .running
            )
            .frame(width: 48)
        }
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
                heroActionPills
            } else {
                compactActionRow
            }
        }
    }

    private var heroActionPills: some View {
        DexterSuggestionHeroActionPills(
            primaryTitle: item.primaryActionTitle,
            adjustOptions: adjustOptions ?? [],
            onDismiss: onDismiss,
            onPrimary: onPrimaryAction,
            onAdjust: onAdjust
        )
        .padding(.top, DexterSpacing.sm)
    }

    private var compactActionRow: some View {
        HStack(spacing: DexterSpacing.sm) {
            Button(action: onPrimaryAction) {
                Text(item.primaryActionTitle)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .padding(.horizontal, DexterSpacing.md)
                    .padding(.vertical, DexterSpacing.sm)
                    .background(
                        Capsule()
                            .fill((profile?.accentColor ?? DexterSurfaceColors.accent).opacity(0.22))
                    )
            }
            .buttonStyle(.plain)
            .pointerCursor()

            if let onSecondaryAction, let secondaryTitle = secondaryActionTitle {
                Button(secondaryTitle, action: onSecondaryAction)
                    .buttonStyle(.plain)
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
            .fill(DexterPastelColors.suggestionSurface(for: item.accentIndex).opacity(0.28))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
            .stroke(
                item.isUnread ? (profile?.accentColor.opacity(0.45) ?? DexterSurfaceColors.border) : DexterSurfaceColors.border.opacity(0.55),
                lineWidth: 1
            )
    }

    private var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
            .fill(DexterSurfaceColors.surfaceElevated.opacity(0.92))
    }

    private var heroCardBorder: some View {
        RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
            .stroke(DexterSurfaceColors.border.opacity(0.4), lineWidth: 1)
    }
}
