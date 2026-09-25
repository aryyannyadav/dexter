//
//  DexterUIComponents.swift
//  leanring-buddy
//

import SwiftUI

// MARK: - Layout primitives

struct DexterPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                    .fill(DS.Colors.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
            )
    }
}

struct DexterSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)
            if let subtitle {
                Text(subtitle)
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DexterStatusChip: View {
    let label: String
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? DexterIdentity.accent : DS.Colors.textTertiary)
                .frame(width: 6, height: 6)
            Text(label)
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(isActive ? DexterIdentity.accent : DS.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isActive ? DexterIdentity.accentSubtle : DS.Colors.surface3)
        )
        .overlay(
            Capsule()
                .stroke(isActive ? DexterIdentity.accentBorder : DS.Colors.borderSubtle, lineWidth: 0.5)
        )
    }
}

// MARK: - Companion mark

struct DexterCompanionMark: View {
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let definition = DexterCharacterCatalog.character(withID: DexterCharacterCatalog.personalCharacterID),
               DexterCharacterAssetCatalog.hasAsset(named: DexterCharacterAssetCatalog.stateAssetName(for: .idle)) {
                DexterCharacterView(
                    definition: definition,
                    appearance: DexterCharacterAppearance.defaultAppearance(forCharacterID: definition.id),
                    state: .idle,
                    size: .custom(size),
                    presentationMode: .stage,
                    animationEnabled: false,
                    profileNameForAccessibility: nil
                )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .fill(DexterIdentity.accentSubtle)
                        .frame(width: size, height: size)
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundColor(DexterIdentity.accent)
                }
            }
        }
        .accessibilityLabel("Dexter companion")
    }
}

// MARK: - Voice

struct DexterVoiceActivationRow: View {
    let isPushToTalkEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DexterIdentity.accent)
            Text(isPushToTalkEnabled ? "Hold ⌃⌥ to talk" : "Type below — push-to-talk is off")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

struct DexterListeningIndicator: View {
    let audioPowerLevel: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(DexterIdentity.accent)
                        .frame(width: 3, height: barHeight(for: index))
                }
            }
            .frame(height: 14, alignment: .bottom)

            Text("Listening")
                .font(DexterIdentity.Typography.bodyMedium())
                .foregroundColor(DexterIdentity.accent)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedPower = min(max(audioPowerLevel, 0.15), 1)
        let base: CGFloat = 4 + CGFloat(index) * 2
        return base + normalizedPower * 6
    }
}

struct DexterThinkingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
            Text("Thinking…")
                .font(DexterIdentity.Typography.bodyMedium())
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

struct DexterSpeakingIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DexterIdentity.accentSecondary)
            Text("Speaking")
                .font(DexterIdentity.Typography.bodyMedium())
                .foregroundColor(DexterIdentity.accentSecondary)
        }
    }
}

struct DexterVoiceStatusCard: View {
    let activationLabel: DexterPanelVoiceActivationLabel
    let interactionState: DexterVoiceInteractionState
    let audioPowerLevel: CGFloat
    let isPushToTalkEnabled: Bool

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                DexterSectionHeader(title: "Voice", subtitle: "Activation & state")

                DexterVoiceActivationRow(isPushToTalkEnabled: isPushToTalkEnabled)

                HStack {
                    DexterStatusChip(label: activationLabel.rawValue, isActive: interactionState != .idle)
                    Spacer()
                }

                switch interactionState {
                case .listening:
                    DexterListeningIndicator(audioPowerLevel: audioPowerLevel)
                case .transcribing, .thinking:
                    DexterThinkingIndicator()
                case .speaking:
                    DexterSpeakingIndicator()
                case .error:
                    DexterStatusChip(label: "Voice unavailable", isActive: true)
                case .idle:
                    EmptyView()
                }
            }
        }
    }
}

// MARK: - Chat

struct DexterChatCard: View {
    let userMessage: String?
    let assistantStreamingText: String
    let assistantFinalText: String

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                DexterSectionHeader(title: "Chat")

                if let userMessage, !userMessage.isEmpty {
                    chatBubble(role: "You", text: userMessage, isUser: true)
                }

                let assistantText = assistantStreamingText.isEmpty ? assistantFinalText : assistantStreamingText
                if !assistantText.isEmpty {
                    chatBubble(role: "Dexter", text: assistantText, isUser: false)
                } else {
                    Text("Ask Dexter anything about your screen or workflow.")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
        }
    }

    private func chatBubble(role: String, text: String, isUser: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(role)
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DS.Colors.textTertiary)
            Text(text)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.small, style: .continuous)
                        .fill(isUser ? DS.Colors.surface3 : DexterIdentity.accentSubtle)
                )
        }
    }
}

// MARK: - Actions

struct DexterActionProposalCard: View {
    let actionDescription: String
    let phaseLabel: DexterPanelActionPhaseLabel

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 8) {
                DexterSectionHeader(title: "Action proposal")
                DexterStatusChip(label: phaseLabel.rawValue, isActive: true)
                Text(actionDescription)
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DexterExecutionProgressCard: View {
    let runtimeState: DexterRuntimeUIState
    let statusDetail: String
    let actionDescription: String

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 8) {
                DexterSectionHeader(title: "Execution", subtitle: statusDetail)
                Text(runtimeState.rawValue)
                    .font(DexterIdentity.Typography.bodyMedium())
                    .foregroundColor(DexterIdentity.accent)
                if !actionDescription.isEmpty {
                    Text(actionDescription)
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct DexterRuntimeFailureCard: View {
    let failurePresentation: DexterRuntimeUIFailurePresentation

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 8) {
                DexterSectionHeader(title: "Something went wrong")
                Text(failurePresentation.whatFailed)
                    .font(DexterIdentity.Typography.bodyMedium())
                    .foregroundColor(DS.Colors.textPrimary)
                Text(failurePresentation.why)
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(failurePresentation.whatYouCanDoNext)
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DexterVerificationResultCard: View {
    let resultLabel: DexterPanelVerificationResultLabel
    let summary: String?

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 8) {
                DexterSectionHeader(title: "Verification")
                DexterStatusChip(
                    label: resultLabel.rawValue,
                    isActive: resultLabel == .success
                )
                if let summary, !summary.isEmpty {
                    Text(summary)
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct DexterTaskStatusCard: View {
    enum Presentation {
        case panel
        case companionInline
    }

    let headline: String
    let detail: String
    var presentation: Presentation = .panel

    var body: some View {
        switch presentation {
        case .panel:
            DexterPanelCard {
                VStack(alignment: .leading, spacing: 8) {
                    DexterSectionHeader(title: "Task status")
                    Text(headline)
                        .font(DexterIdentity.Typography.bodyMedium())
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(detail)
                        .font(DexterIdentity.Typography.monoCaption())
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
        case .companionInline:
            VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                Text(headline)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                Text(detail)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dexterCompanionInlineBannerChrome()
        }
    }
}

struct DexterInteractiveOnboardingCard: View {
    @ObservedObject var interactiveOnboardingStore: DexterInteractiveOnboardingStore

    var body: some View {
        DexterPanelCard {
            VStack(alignment: .leading, spacing: 8) {
                DexterSectionHeader(title: "Get to know Dexter", subtitle: interactiveOnboardingStore.panelHeadline)
                Text(interactiveOnboardingStore.panelDetail)
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DexterRuntimeUIStateBanner: View {
    @ObservedObject var runtimeUIStateStore: DexterRuntimeUIStateStore

    var body: some View {
        if runtimeUIStateStore.currentState != .idle {
            DexterPanelCard {
                VStack(alignment: .leading, spacing: 6) {
                    DexterSectionHeader(title: "Status", subtitle: runtimeUIStateStore.statusDetail)
                    Text(runtimeUIStateStore.currentState.rawValue)
                        .font(DexterIdentity.Typography.bodyMedium())
                        .foregroundColor(DexterIdentity.accent)
                }
            }
        }
    }
}

struct DexterDemonstrationPhaseBanner: View {
    @ObservedObject var phaseStore: DexterRuntimeUIStateStore

    var body: some View {
        DexterRuntimeUIStateBanner(runtimeUIStateStore: phaseStore)
    }
}

struct DexterFloatingCompanionHeader: View {
    var activeProfile: DexterProfile?
    var characterState: DexterCharacterState = .idle
    let statusChipLabel: String
    let isStatusActive: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let activeProfile {
                DexterAvatar(
                    profile: activeProfile,
                    size: DexterAvatarSize.sm,
                    characterState: characterState,
                    animationEnabled: isStatusActive
                )
            } else {
                DexterCompanionMark()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activeProfile?.name ?? "Dexter")
                    .font(DexterIdentity.Typography.title())
                    .foregroundColor(DS.Colors.textPrimary)
                DexterStatusChip(label: statusChipLabel, isActive: isStatusActive)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DS.Colors.surface3))
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }
}
