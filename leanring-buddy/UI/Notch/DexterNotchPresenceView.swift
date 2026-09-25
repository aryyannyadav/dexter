//
//  DexterNotchPresenceView.swift
//  leanring-buddy
//

import Combine
import SwiftUI

struct DexterNotchPresenceView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var chromeController: DexterNotchChromeController
    @ObservedObject var attentionStore: DexterNotchAttentionStore
    @ObservedObject var recommendationStore: DexterNotchRecommendationStore
    @ObservedObject var ambientStore: DexterNotchAmbientStore

    @State private var hoverCollapseTask: Task<Void, Never>?
    @State private var errorShakeOffset: CGFloat = 0

    private var ambient: DexterAmbientResolvedState {
        ambientStore.resolvedState
    }

    var body: some View {
        Group {
            switch chromeController.chromeMode {
            case .idle:
                compactPresence
            case .hovering:
                expandedAmbientSurface(compact: false)
            case .expanded:
                expandedAmbientSurface(compact: false)
            }
        }
        .animation(DexterMotionPreferences.shouldReduceMotion ? nil : DexterAnimation.gentleEase, value: chromeController.chromeMode)
        .animation(DexterMotionPreferences.shouldReduceMotion ? nil : DexterAnimation.gentleEase, value: ambient.ambientState)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ambient.accessibilityLabel)
        .onHover { isHovering in
            handleHoverChanged(isHovering)
        }
        .onChange(of: ambient.ambientState) { _, newState in
            if newState == .error {
                triggerErrorShake()
            }
            if chromeController.chromeMode == .expanded {
                attentionStore.clearAttentionForUserInteraction()
            }
        }
    }

    // MARK: - Compact

    private var compactPresence: some View {
        HStack(spacing: DexterSpacing.sm) {
            notchCharacter(size: .custom(32))

            if ambient.ambientState != .idle {
                Text(ambient.compactStatusLine)
                    .font(DexterTypography.caption())
                    .foregroundColor(activeAccentColor.opacity(0.9))
                    .lineLimit(1)
            }

            if attentionStore.showsAttentionBadge {
                Circle()
                    .fill(activeAccentColor)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, DexterSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Capsule(style: .continuous))
        .offset(x: errorShakeOffset)
        .onTapGesture {
            handleCompactTap()
        }
        .background(compactBackground)
    }

    private var compactBackground: some View {
        let shadow = DexterShadow.ambientNotch()
        return Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        DexterSurfaceColors.surfaceElevated.opacity(0.96),
                        DexterSurfaceColors.surface.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                activeAccentColor.opacity(0.42),
                                DexterPastelColors.lavender.opacity(0.28)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }

    // MARK: - Expanded / hover

    private func expandedAmbientSurface(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            HStack(alignment: .top, spacing: DexterSpacing.md) {
                notchCharacter(size: .custom(44))
                VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                    Text(ambient.activeProfileName)
                        .font(DexterTypography.bodyMedium())
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                    Text(ambient.statusTitle)
                        .font(DexterTypography.headline())
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                        .lineLimit(2)
                    if !ambient.statusDetail.isEmpty {
                        Text(ambient.statusDetail)
                            .font(DexterTypography.secondary())
                            .foregroundColor(DexterColors.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if chromeController.chromeMode == .expanded {
                    closeButton
                }
            }

            actionRow
        }
        .padding(DexterSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x: errorShakeOffset)
        .background(panelBackground)
    }

    private var closeButton: some View {
        Button {
            chromeController.collapseFromEscape()
            if ambient.ambientState == .permission {
                chromeController.releaseHeldExpansion()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DexterColors.textSecondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(DexterSurfaceColors.surface))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .accessibilityLabel("Close")
    }

    @ViewBuilder
    private var actionRow: some View {
        switch ambient.ambientState {
        case .permission:
            HStack(spacing: DexterSpacing.sm) {
                DexterButton(title: "Allow", action: approvePermission)
                    .accessibilityLabel("Allow")
                DexterSecondaryButton(title: "Deny", action: denyPermission)
                    .accessibilityLabel("Deny")
                Spacer(minLength: 0)
            }
        case .error:
            HStack(spacing: DexterSpacing.sm) {
                DexterButton(title: "Try again", action: retryFromError)
                    .accessibilityLabel("Try again")
                DexterSecondaryButton(title: "Open Dexter", action: openDexterHome)
                    .accessibilityLabel("Open Dexter")
                Spacer(minLength: 0)
            }
        case .suggestion:
            VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                DexterSuggestionHeroActionPills(
                    primaryTitle: primarySuggestionActionTitle,
                    adjustOptions: activeSuggestionAdjustOptions,
                    onDismiss: dismissActiveSuggestion,
                    onPrimary: performSuggestionPrimaryAction,
                    onAdjust: performSuggestionAdjust
                )
                Button("Open Dexter") { openDexterHome() }
                    .buttonStyle(.plain)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textMuted)
                    .pointerCursor()
            }
        case .success:
            HStack(spacing: DexterSpacing.sm) {
                Text("✓ Done")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterColors.textSecondary)
                Spacer()
                DexterSecondaryButton(title: "Open Dexter", action: openDexterHome)
            }
        case .working, .listening, .thinking, .speaking:
            HStack(spacing: DexterSpacing.sm) {
                Spacer()
                DexterSecondaryButton(title: "Open Dexter", action: openDexterHome)
            }
        case .idle:
            HStack(spacing: DexterSpacing.sm) {
                Spacer()
                DexterSecondaryButton(title: "Open Dexter", action: openDexterHome)
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: DexterRadii.large, style: .continuous)
            .fill(DexterSurfaceColors.surface.opacity(0.97))
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.large, style: .continuous)
                    .stroke(activeAccentColor.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 14, y: 6)
    }

    @ViewBuilder
    private func notchCharacter(size: DexterCharacterSize) -> some View {
        DexterNotchActiveCharacterView(
            companionManager: companionManager,
            characterState: ambient.characterState,
            size: size,
            presentationMode: DexterCharacterAssetCatalog.presentationModeForCompactSurfaces(state: ambient.characterState),
            animationEnabled: ambient.ambientState != .idle
        )
    }

    private var activeAccentColor: Color {
        companionManager.dexterProfileStore.activeProfile?.accentColor ?? DexterPastelColors.lavender
    }

    private var primarySuggestionActionTitle: String {
        if let item = ambient.phase5Suggestion {
            return item.primaryActionTitle
        }
        if let recommendation = ambient.notchRecommendation {
            return recommendation.primaryActionTitle
        }
        return "Do it"
    }

    private var activeSuggestionAdjustOptions: [DexterSuggestionAdjustOption] {
        guard let item = ambient.phase5Suggestion,
              case .context(let suggestion) = item else {
            return []
        }
        return suggestion.adjustOptions ?? []
    }

    private func dismissActiveSuggestion() {
        if let item = ambient.phase5Suggestion {
            companionManager.dexterSuggestionStore.dismissHomeSuggestion(item)
        }
        chromeController.collapseToIdle()
    }

    private func performSuggestionAdjust(_ option: DexterSuggestionAdjustOption) {
        guard let item = ambient.phase5Suggestion else { return }
        companionManager.dexterSuggestionStore.acceptHomeSuggestion(
            item,
            userPromptOverride: option.userPrompt
        )
        chromeController.collapseToIdle()
        NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
    }

    // MARK: - Actions

    private func handleCompactTap() {
        switch ambient.ambientState {
        case .idle:
            openDexterHome()
        case .permission:
            chromeController.holdExpandedForInteraction()
        case .suggestion:
            chromeController.expand()
        case .error:
            chromeController.expand()
        case .working, .listening, .thinking, .speaking:
            openDexterHome()
        case .success:
            chromeController.collapseToIdle()
        }
    }

    private func openDexterHome() {
        NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
        chromeController.collapseToIdle()
    }

    private func approvePermission() {
        companionManager.approvePendingActionConfirmation()
        chromeController.releaseHeldExpansion()
    }

    private func denyPermission() {
        companionManager.cancelPendingActionConfirmation()
        chromeController.releaseHeldExpansion()
    }

    private func retryFromError() {
        if let recommendation = ambient.notchRecommendation, recommendation.kind == .agentFailure {
            recommendationStore.handlePrimaryAction(for: recommendation)
        } else {
            companionManager.retryLastAgentActionFromHUD()
        }
        chromeController.collapseToIdle()
    }

    private func performSuggestionPrimaryAction() {
        if let item = ambient.phase5Suggestion {
            companionManager.dexterSuggestionStore.acceptHomeSuggestion(item)
            chromeController.collapseToIdle()
            return
        }
        if let recommendation = ambient.notchRecommendation {
            recommendationStore.handlePrimaryAction(for: recommendation)
            chromeController.collapseToIdle()
        }
    }

    private func handleHoverChanged(_ isHovering: Bool) {
        hoverCollapseTask?.cancel()
        if isHovering {
            if chromeController.chromeMode == .idle {
                chromeController.enterHover()
            }
            return
        }

        hoverCollapseTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            chromeController.retractAfterPointerExit()
        }
    }

    private func triggerErrorShake() {
        guard !DexterMotionPreferences.shouldReduceMotion else { return }
        withAnimation(.default.speed(2)) {
            errorShakeOffset = 4
        }
        Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run {
                withAnimation(.default.speed(2)) {
                    errorShakeOffset = -4
                }
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    errorShakeOffset = 0
                }
            }
        }
    }
}

@MainActor
final class DexterNotchChromeController: ObservableObject {
    @Published private(set) var chromeMode: DexterNotchChromeMode = .idle

    private var autoCollapseTask: Task<Void, Never>?
    private var holdsExpandedForInteraction = false

    func enterHover() {
        guard chromeMode == .idle else { return }
        chromeMode = .hovering
    }

    func expand() {
        autoCollapseTask?.cancel()
        chromeMode = .expanded
    }

    func collapseFromEscape() {
        holdsExpandedForInteraction = false
        autoCollapseTask?.cancel()
        chromeMode = .idle
    }

    func collapseToIdle() {
        holdsExpandedForInteraction = false
        autoCollapseTask?.cancel()
        chromeMode = .idle
    }

    func retractAfterPointerExit() {
        switch chromeMode {
        case .hovering:
            if !holdsExpandedForInteraction {
                chromeMode = .idle
            }
        case .expanded:
            break
        case .idle:
            break
        }
    }

    func brieflyExpand(durationSeconds: TimeInterval) {
        holdsExpandedForInteraction = false
        autoCollapseTask?.cancel()
        if chromeMode == .idle {
            chromeMode = .hovering
        }
        autoCollapseTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(durationSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if !holdsExpandedForInteraction, chromeMode == .hovering {
                chromeMode = .idle
            }
        }
    }

    func holdExpandedForInteraction() {
        holdsExpandedForInteraction = true
        autoCollapseTask?.cancel()
        chromeMode = .expanded
    }

    func releaseHeldExpansion() {
        holdsExpandedForInteraction = false
        chromeMode = .idle
    }
}
