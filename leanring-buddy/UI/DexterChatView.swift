//
//  DexterChatView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterChatView: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var composerText: String

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            DexterPointInvokeBanner(
                session: companionManager.activePointInvokeSession,
                isPreparing: companionManager.isPreparingPointInvokeSession,
                onDismiss: { companionManager.clearActivePointInvokeSession() }
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if companionManager.dexterScreenContextUIState == .analyzingScreen
                && !companionManager.isPreparingPointInvokeSession {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing your screen…")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(DexterIdentity.accentSubtle.opacity(0.35))
            }

            Divider().background(DS.Colors.borderSubtle)

            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            taskStatusBanner

                            if companionManager.dexterChatMessages.isEmpty
                                && companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty
                                && companionManager.voiceInteractionState != .thinking {
                                HStack {
                                    Spacer(minLength: 0)
                                    if companionManager.activePointInvokeSession != nil {
                                        pointInvokePromptSuggestions
                                    } else {
                                        DexterEmptyState { suggestion in
                                            composerText = suggestion
                                            companionManager.submitTextMessageToDexter(suggestion)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.top, 48)
                            } else {
                                ForEach(companionManager.dexterChatMessages) { message in
                                    DexterChatBubble(message: message)
                                        .id(message.id)
                                }

                                if shouldShowStreamingBubble {
                                    DexterChatBubble(
                                        message: DexterChatMessage(
                                            role: .assistant,
                                            text: streamingDisplayText,
                                            isError: companionManager.dexterChatErrorMessage != nil
                                        ),
                                        showsTypingIndicator: companionManager.voiceInteractionState == .thinking
                                            && companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty
                                    )
                                    .id("streaming-assistant")
                                }
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: companionManager.dexterChatMessages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: companionManager.dexterVoiceCoordinator.streamingResponseText) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                overlays
            }

            Divider().background(DS.Colors.borderSubtle)
            DexterComposer(companionManager: companionManager, messageText: $composerText)
        }
        .background(DS.Colors.background)
    }

    @ViewBuilder
    private var taskStatusBanner: some View {
        if let headline = DexterPanelPresentation.taskStatusHeadline(for: companionManager.panelActiveWorkflowTask),
           let detail = DexterPanelPresentation.taskStatusDetail(for: companionManager.panelActiveWorkflowTask) {
            DexterTaskStatusCard(headline: headline, detail: detail)
        }
    }

    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chat")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Text(DexterProductCopy.tagline)
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.textTertiary)
            }
            Spacer()
            DexterContextIndicator(
                uiState: companionManager.dexterScreenContextUIState,
                contextualLabel: companionManager.activePointInvokeSession?.contextualIndicatorLabel
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(DS.Colors.surface1)
    }

    @ViewBuilder
    private var overlays: some View {
        VStack {
            if let confirmation = companionManager.actionConfirmationPresentation {
                DexterActionConfirmationView(
                    presentation: confirmation,
                    onCancel: { companionManager.cancelPendingActionConfirmation() },
                    onAllow: { companionManager.approvePendingActionConfirmation() }
                )
                .padding()
            }
            Spacer()
        }
    }

    private var shouldShowStreamingBubble: Bool {
        companionManager.voiceInteractionState == .thinking
            || companionManager.voiceInteractionState == .speaking
            || !companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty
    }

    private var streamingDisplayText: String {
        let streaming = companionManager.dexterVoiceCoordinator.streamingResponseText
        if !streaming.isEmpty { return streaming }
        if companionManager.voiceInteractionState == .speaking {
            return "Speaking…"
        }
        if let spokenError = companionManager.dexterSpokenResponseErrorMessage {
            return spokenError
        }
        if let error = companionManager.dexterChatErrorMessage { return error }
        return "Dexter is thinking…"
    }

    private var pointInvokePromptSuggestions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking:")
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)
            DexterSuggestionCard(title: "What is this?") {
                companionManager.submitTextMessageToDexter("What is this?")
            }
            DexterSuggestionCard(title: "Why is this happening?") {
                companionManager.submitTextMessageToDexter("Why is this happening?")
            }
            DexterSuggestionCard(title: "Teach me this.") {
                companionManager.submitTextMessageToDexter("Teach me this.")
            }
        }
        .frame(maxWidth: 420)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if shouldShowStreamingBubble {
                proxy.scrollTo("streaming-assistant", anchor: .bottom)
            } else if let lastId = companionManager.dexterChatMessages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

private struct DexterChatBubble: View {
    let message: DexterChatMessage
    var showsTypingIndicator: Bool = false

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(message.isError ? DS.Colors.destructiveText : DS.Colors.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(bubbleFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.Colors.borderSubtle.opacity(message.role == .user ? 0 : 1), lineWidth: 1)
                    )

                if showsTypingIndicator {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, 4)
                }
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubbleFill: Color {
        if message.isError { return DS.Colors.destructive.opacity(0.12) }
        switch message.role {
        case .user:
            return DexterIdentity.accentSubtle
        case .assistant:
            return DS.Colors.surface2
        }
    }
}
