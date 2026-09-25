//
//  DexterConversationMessageGroupView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterConversationMessageGroupView: View {
    let group: DexterConversationMessageGroup
    let profile: DexterProfile
    let columnMaxWidth: CGFloat
    var characterState: DexterCharacterState = .idle
    var animateCharacter: Bool = false
    var presentationStyle: DexterConversationPresentationStyle = .standard
    var onEditUserMessage: ((String) -> Void)?
    var onResendUserMessage: ((String) -> Void)?
    var onRetryAssistantResponse: (() -> Void)?
    var onDeleteMessage: ((UUID) -> Void)?
    var canDeleteMessage: ((DexterChatMessage) -> Bool)? = { _ in true }

    @State private var hoveredMessageId: UUID?

    private let avatarColumnWidth: CGFloat = 36

    private var assistantBubbleMaxWidth: CGFloat {
        min(
            columnMaxWidth * DexterMessageMetrics.regularMaxWidthRatio,
            DexterMessageMetrics.assistantBubbleAbsoluteMaxWidth
        )
    }

    private var userBubbleMaxWidth: CGFloat {
        min(
            columnMaxWidth * DexterMessageMetrics.compactMaxWidthRatio,
            DexterMessageMetrics.userBubbleAbsoluteMaxWidth
        )
    }

    var body: some View {
        VStack(alignment: presentationStyle == .centeredCompanion ? .center : .leading, spacing: DexterSpacing.sm) {
            if group.showsTimestamp, let timestamp = group.timestamp {
                Text(DexterConversationTimestampFormatter.label(for: timestamp))
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, DexterSpacing.xs)
            }

            switch group.role {
            case .assistant:
                assistantGroup
            case .user:
                userGroup
            }
        }
        .frame(maxWidth: .infinity, alignment: presentationStyle == .centeredCompanion ? .center : .leading)
    }

    private var assistantGroup: some View {
        HStack(alignment: .top, spacing: DexterMessageMetrics.avatarToBubbleGap) {
            DexterAvatar(
                profile: profile,
                size: DexterAvatarSize.md,
                characterState: characterState,
                animationEnabled: animateCharacter
            )
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: DexterMessageMetrics.intraGroupSpacing) {
                ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                    assistantMessageBubble(message: message, isLastInGroup: index == group.messages.count - 1)
                }
            }

            Spacer(minLength: 48)
        }
    }

    private var userGroup: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: avatarColumnWidth + DexterMessageMetrics.avatarToBubbleGap)

            VStack(alignment: .trailing, spacing: DexterMessageMetrics.intraGroupSpacing) {
                ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                    userMessageBubble(message: message, isLastInGroup: index == group.messages.count - 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func assistantMessageBubble(
        message: DexterChatMessage,
        isLastInGroup: Bool,
        showsTail: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: DexterSpacing.xs) {
            if message.isError {
                DexterConversationErrorBubble(
                    profile: profile,
                    message: message,
                    maxWidth: assistantBubbleMaxWidth,
                    onRetry: onRetryAssistantResponse
                )
            } else {
                DexterMessageBubble(
                    text: message.text,
                    isError: false,
                    showsTail: showsTail && isLastInGroup,
                    maxWidth: assistantBubbleMaxWidth
                )
                .onHover { isHovered in
                    hoveredMessageId = isHovered ? message.id : nil
                }
                .overlay(alignment: .topTrailing) {
                    if hoveredMessageId == message.id {
                        DexterAssistantMessageActions(
                            messageText: DexterVisionObservationParser.userFacingChatDisplayText(from: message.text),
                            onRetry: onRetryAssistantResponse,
                            onDelete: canDeleteMessage?(message) == true ? { onDeleteMessage?(message.id) } : nil
                        )
                        .offset(x: 4, y: -8)
                    }
                }
                .contextMenu {
                    Button("Copy") {
                        DexterConversationClipboard.copy(
                            DexterVisionObservationParser.userFacingChatDisplayText(from: message.text)
                        )
                    }
                    if canDeleteMessage?(message) == true, let onDeleteMessage {
                        Button("Delete", role: .destructive) {
                            onDeleteMessage(message.id)
                        }
                    }
                    if let onRetryAssistantResponse {
                        Button("Retry") { onRetryAssistantResponse() }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.name) said: \(message.text)")
    }

    private func userMessageBubble(message: DexterChatMessage, isLastInGroup: Bool) -> some View {
        UserMessageBubble(
            text: message.text,
            isError: message.isError,
            showsTail: isLastInGroup,
            accentColor: profile.accentColor,
            maxWidth: userBubbleMaxWidth
        )
        .onHover { isHovered in
            hoveredMessageId = isHovered ? message.id : nil
        }
        .overlay(alignment: .topLeading) {
            if hoveredMessageId == message.id {
                DexterUserMessageActions(
                    messageText: message.text,
                    onEdit: { onEditUserMessage?(message.text) },
                    onResend: { onResendUserMessage?(message.text) },
                    onDelete: canDeleteMessage?(message) == true ? { onDeleteMessage?(message.id) } : nil
                )
                .offset(x: -4, y: -8)
            }
        }
        .contextMenu {
            Button("Copy") { DexterConversationClipboard.copy(message.text) }
            if canDeleteMessage?(message) == true, let onDeleteMessage {
                Button("Delete", role: .destructive) {
                    onDeleteMessage(message.id)
                }
            }
            if let onEditUserMessage {
                Button("Edit") { onEditUserMessage(message.text) }
            }
            if let onResendUserMessage {
                Button("Resend") { onResendUserMessage(message.text) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You said: \(message.text)")
    }
}

private struct DexterAssistantMessageActions: View {
    let messageText: String
    var onRetry: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            DexterMessageActionChip(title: "Copy", accessibilityLabel: "Copy message") {
                DexterConversationClipboard.copy(messageText)
            }
            if let onDelete {
                DexterMessageActionChip(title: "Delete", accessibilityLabel: "Delete message", action: onDelete)
            }
            if let onRetry {
                DexterMessageActionChip(title: "Retry", accessibilityLabel: "Retry response", action: onRetry)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DexterRadii.small, style: .continuous)
                .fill(DexterSurfaceColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.small, style: .continuous)
                .stroke(DexterSurfaceColors.border, lineWidth: 1)
        )
    }
}

private struct DexterUserMessageActions: View {
    let messageText: String
    var onEdit: () -> Void
    var onResend: () -> Void
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            DexterMessageActionChip(title: "Copy", accessibilityLabel: "Copy message") {
                DexterConversationClipboard.copy(messageText)
            }
            if let onDelete {
                DexterMessageActionChip(title: "Delete", accessibilityLabel: "Delete message", action: onDelete)
            }
            DexterMessageActionChip(title: "Edit", accessibilityLabel: "Edit message", action: onEdit)
            DexterMessageActionChip(title: "Resend", accessibilityLabel: "Resend message", action: onResend)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DexterRadii.small, style: .continuous)
                .fill(DexterSurfaceColors.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.small, style: .continuous)
                .stroke(DexterSurfaceColors.border, lineWidth: 1)
        )
    }
}

private struct DexterMessageActionChip: View {
    let title: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DexterTypography.metadata())
                .foregroundColor(DexterSurfaceColors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(isHovered ? 0.08 : 0))
                )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct DexterConversationErrorBubble: View {
    let profile: DexterProfile
    let message: DexterChatMessage
    let maxWidth: CGFloat
    var onRetry: (() -> Void)?

    @State private var showsTechnicalDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.sm) {
            DexterMessageBubble(
                text: conversationalErrorSummary,
                isError: true,
                showsTail: true,
                maxWidth: maxWidth
            )

            HStack(spacing: DexterSpacing.sm) {
                if let onRetry {
                    Button("Try again", action: onRetry)
                        .buttonStyle(.plain)
                        .font(DexterTypography.metadata())
                        .foregroundColor(profile.accentColor)
                        .pointerCursor()
                }
                Button(showsTechnicalDetails ? "Hide details" : "Details") {
                    showsTechnicalDetails.toggle()
                }
                .buttonStyle(.plain)
                .font(DexterTypography.metadata())
                .foregroundColor(DexterSurfaceColors.textMuted)
                .pointerCursor()
            }

            if showsTechnicalDetails {
                Text(message.text)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textMuted)
                    .textSelection(.enabled)
            }
        }
    }

    private var conversationalErrorSummary: String {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 120 {
            return trimmed.isEmpty ? "Something went wrong." : trimmed
        }
        return "Something went wrong while handling that request."
    }
}
