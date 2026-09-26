//
//  DexterHomeChatPane.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeChatPane: View {
    @ObservedObject var companionManager: CompanionManager
    @Binding var composerText: String
    var onOpenProfile: ((UUID) -> Void)?

    private var liveCharacterState: DexterCharacterState {
        companionManager.activeCharacterState
    }

    @StateObject private var executionProgressTracker = DexterConversationProgressTracker()
    @State private var stickToBottom = true
    @State private var selectedRoutineId: UUID?
    @State private var isRoutinesListPresented = false

    private let bottomAnchorIdentifier = "conversation-bottom-anchor"

    var body: some View {
        VStack(spacing: 0) {
            homeHeader

            companionInlineBanners
                .padding(.horizontal, DexterConversationLayout.messageColumnHorizontalPadding)
                .padding(.top, DexterSpacing.sm)

            ZStack(alignment: .top) {
                messageScrollArea
                confirmationOverlay
            }

            if let inferenceSuggestion = companionManager.pendingMemoryInferenceSuggestion {
                DexterMemoryInferencePromptCard(
                    suggestion: inferenceSuggestion,
                    onRemember: { companionManager.confirmPendingMemoryInferenceForActiveDexter() },
                    onDecline: { companionManager.declinePendingMemoryInference() }
                )
                .frame(maxWidth: DexterCompanionLayout.inlineBannerMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DexterConversationLayout.messageColumnHorizontalPadding)
                .padding(.top, DexterSpacing.sm)
            }

            DexterHomeChatComposerStack(
                companionManager: companionManager,
                messageText: $composerText,
                activeProfile: resolvedConversationProfile,
                characterState: liveCharacterState,
                showsCharacterPeek: showsWorkspaceCharacterPeek
            )
        }
        .background(
            ZStack {
                DexterSurfaceColors.background
                LinearGradient(
                    colors: [
                        DexterPastelColors.lavender.opacity(0.03),
                        Color.clear,
                        DexterPastelColors.sky.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(alignment: .bottomLeading) {
            if showsWorkspaceRoutinesStrip {
                DexterHomeRoutinesSection(
                    companionManager: companionManager,
                    onViewAll: { isRoutinesListPresented = true },
                    onCreateRoutine: { presentRoutineCreation() },
                    onOpenRoutine: { selectedRoutineId = $0 }
                )
                .padding(.leading, DexterConversationLayout.messageColumnHorizontalPadding)
                .padding(.bottom, 96)
                .frame(maxWidth: 280, alignment: .leading)
            }
        }
        .onChange(of: companionManager.shouldPresentRoutinesList) { _, shouldPresent in
            if shouldPresent {
                isRoutinesListPresented = true
                companionManager.shouldPresentRoutinesList = false
            }
        }
        .onChange(of: companionManager.pendingUniversalCommandRoutineId) { _, routineId in
            guard let routineId else { return }
            selectedRoutineId = routineId
            companionManager.pendingUniversalCommandRoutineId = nil
        }
        .onReceive(companionManager.dexterRuntimeUIStateStore.$statusDetail) { detail in
            ingestExecutionProgress(statusDetail: detail)
        }
        .onReceive(companionManager.dexterRuntimeUIStateStore.$currentState) { state in
            ingestExecutionProgress(statusDetail: companionManager.dexterRuntimeUIStateStore.statusDetail)
            if state.isTerminal {
                executionProgressTracker.markAllStepsCompletedIfNeeded()
            }
        }
        .sheet(isPresented: createRoutineFlowPresentedBinding) {
            if companionManager.dexterRoutineStore.pendingCreationDraft != nil {
                DexterRoutineCreateFlowView(
                    companionManager: companionManager,
                    routineStore: companionManager.dexterRoutineStore,
                    onDismiss: {
                        companionManager.dexterRoutineStore.isCreateFlowPresented = false
                    }
                )
            }
        }
        .sheet(isPresented: $isRoutinesListPresented) {
            DexterRoutinesListSheet(companionManager: companionManager)
        }
        .sheet(isPresented: Binding(
            get: { selectedRoutineId != nil },
            set: { isPresented in
                if !isPresented { selectedRoutineId = nil }
            }
        )) {
            if let routineId = selectedRoutineId {
                DexterRoutineDetailView(
                    companionManager: companionManager,
                    routineId: routineId,
                    onDismiss: { selectedRoutineId = nil }
                )
            }
        }
    }

    private var createRoutineFlowPresentedBinding: Binding<Bool> {
        Binding(
            get: { companionManager.dexterRoutineStore.isCreateFlowPresented },
            set: { companionManager.dexterRoutineStore.isCreateFlowPresented = $0 }
        )
    }

    private func presentRoutineCreation() {
        let profileId = companionManager.dexterProfileStore.activeProfileId
            ?? companionManager.dexterProfileStore.profiles.first?.id
            ?? UUID()
        companionManager.dexterRoutineStore.presentCreationDraft(
            DexterRoutineCreationDraft(
                naturalLanguageInput: "",
                name: "",
                instruction: "",
                description: "",
                trigger: DexterRoutineTrigger(kind: .manualOnly),
                dexterProfileId: profileId,
                requiredCapabilityIDs: []
            )
        )
    }

    private var homeHeader: some View {
        Group {
            switch companionManager.homeWorkspacePresentation {
            case .dashboard:
                HStack {
                    Spacer(minLength: 0)
                    windowLayoutMenu
                }
                .padding(.horizontal, DexterSpacing.xl)
                .padding(.vertical, DexterSpacing.sm)
            case .dexterWorkspace:
                DexterChatWorkspaceHeader(
                    profile: resolvedConversationProfile,
                    characterState: liveCharacterState,
                    onOpenProfile: resolvedConversationProfile.map { profile in
                        { onOpenProfile?(profile.id) }
                    },
                    onBack: {
                        companionManager.openDexterHomeDashboard()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var companionInlineBanners: some View {
        let showsPointBanner = companionManager.isPreparingPointInvokeSession
            || companionManager.activePointInvokeSession != nil
        let showsVoiceBanner = companionManager.voiceInputErrorPresentation != nil
        let showsAnalyzing = companionManager.dexterScreenContextUIState == .analyzingScreen
            && !companionManager.isPreparingPointInvokeSession

        if showsPointBanner || showsVoiceBanner || showsAnalyzing {
            VStack(spacing: DexterSpacing.sm) {
                DexterPointInvokeBanner(
                    session: companionManager.activePointInvokeSession,
                    isPreparing: companionManager.isPreparingPointInvokeSession,
                    pointAskPresence: companionManager.pointAskPresenceState,
                    onDismiss: { companionManager.clearActivePointInvokeSession() }
                )

                if let voiceInputError = companionManager.voiceInputErrorPresentation {
                    DexterVoiceInputErrorBanner(
                        presentation: voiceInputError,
                        onOpenVoiceSettings: {
                            companionManager.openVoiceSettingsFromVoiceInputError()
                        },
                        onDismiss: {
                            companionManager.clearVoiceInputErrorPresentation()
                        }
                    )
                }

                if showsAnalyzing {
                    analyzingBanner
                }
            }
            .frame(maxWidth: DexterCompanionLayout.inlineBannerMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var showsWorkspaceCharacterPeek: Bool {
        false
    }

    private var showsWorkspaceRoutinesStrip: Bool {
        if case .dashboard = companionManager.homeWorkspacePresentation {
            return false
        }
        return true
    }

    private var conversationPresentationStyle: DexterConversationPresentationStyle {
        .standard
    }

    private var windowLayoutMenu: some View {
        Menu {
            ForEach(DexterHomeWindowLayoutMode.allCases, id: \.self) { mode in
                Button(mode.menuTitle) {
                    NotificationCenter.default.post(name: .dexterHomeApplyWindowLayoutMode, object: mode)
                }
            }
        } label: {
            Image(systemName: "rectangle.center.inset.filled")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DexterSurfaceColors.textSecondary)
                .frame(width: DexterMetrics.iconButtonSize, height: DexterMetrics.iconButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                        .fill(DexterColors.inputBackground)
                )
        }
        .menuStyle(.borderlessButton)
        .help("Window size")
        .pointerCursor()
    }

    private var analyzingBanner: some View {
        HStack(spacing: DexterSpacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text("Taking a quick look at your screen…")
                .font(DexterTypography.secondary())
                .foregroundColor(DexterSurfaceColors.textSecondary)
            Spacer(minLength: 0)
        }
        .dexterCompanionInlineBannerChrome()
    }

    private var messageScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(
                    alignment: conversationPresentationStyle == .centeredCompanion ? .center : .leading,
                    spacing: DexterConversationLayout.messageGroupSpacing
                ) {
                    taskStatusBanner
                        .frame(maxWidth: conversationColumnMaxWidth)
                        .frame(maxWidth: .infinity)

                    if showsConversationEmptyState {
                        conversationEmptyContent
                    } else if companionManager.activePointInvokeSession != nil
                        && companionManager.dexterChatMessages.isEmpty
                        && !shouldShowStreamingRow {
                        pointInvokePromptSuggestions
                            .frame(maxWidth: conversationColumnMaxWidth)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        messageGroupsContent
                    }

                    if showsExecutionProgress {
                        DexterProgressMessage(
                            profile: resolvedConversationProfile ?? fallbackProfile,
                            headline: executionProgressHeadline,
                            steps: executionProgressTracker.steps,
                            isExpanded: $executionProgressTracker.isExpanded
                        )
                        .frame(maxWidth: conversationColumnMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if shouldShowStreamingRow {
                        streamingAssistantRow
                            .frame(maxWidth: conversationColumnMaxWidth)
                            .frame(
                                maxWidth: .infinity,
                                alignment: conversationPresentationStyle == .centeredCompanion ? .center : .leading
                            )
                            .id("streaming-assistant")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorIdentifier)
                }
                .padding(.horizontal, DexterConversationLayout.messageColumnHorizontalPadding)
                .padding(.vertical, DexterSpacing.lg)
                .frame(maxWidth: conversationColumnMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if value.translation.height > 8 {
                            stickToBottom = false
                        }
                    }
            )
            .onChange(of: companionManager.dexterChatMessages.count) { _, _ in
                if companionManager.dexterChatMessages.last?.role == .user {
                    stickToBottom = true
                }
                scrollToBottomIfPinned(proxy: proxy)
            }
            .onChange(of: companionManager.dexterVoiceCoordinator.streamingResponseText) { _, _ in
                scrollToBottomIfPinned(proxy: proxy)
            }
            .onChange(of: executionProgressTracker.steps.count) { _, _ in
                scrollToBottomIfPinned(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private var conversationEmptyContent: some View {
        if case .dashboard = companionManager.homeWorkspacePresentation {
            DexterHomeWorkspaceWelcomeView(
                companionManager: companionManager,
                onOpenProfile: onOpenProfile
            )
        } else if let profile = resolvedConversationProfile {
            DexterConversationEmptyState(
                companionManager: companionManager,
                profile: profile,
                highlightedFirstRunPrompt: companionManager.pendingOnboardingFirstSuggestionPrompt
            )
            .onChange(of: companionManager.dexterChatMessages.count) { _, _ in
                if !companionManager.dexterChatMessages.isEmpty {
                    stickToBottom = true
                }
            }
        }
    }

    private var messageGroupsContent: some View {
        ForEach(messageGroups) { group in
            DexterConversationMessageGroupView(
                group: group,
                profile: resolvedConversationProfile ?? fallbackProfile,
                columnMaxWidth: conversationColumnMaxWidth,
                characterState: characterState(for: group),
                animateCharacter: shouldAnimateCharacter(for: group),
                presentationStyle: conversationPresentationStyle,
                onEditUserMessage: { text in
                    composerText = text
                },
                onResendUserMessage: { text in
                    stickToBottom = true
                    companionManager.submitTextMessageToDexter(text)
                },
                onRetryAssistantResponse: {
                    retryLastUserTurn()
                },
                onDeleteMessage: { messageId in
                    companionManager.deleteDexterChatMessage(messageId: messageId)
                },
                canDeleteMessage: { message in
                    canDeleteChatMessage(message)
                }
            )
            .id(group.id)
        }
    }

    private var streamingAssistantRow: some View {
        let profile = resolvedConversationProfile ?? fallbackProfile
        let streamingText = companionManager.dexterVoiceCoordinator.streamingResponseText

        let bubbleMaxWidth = min(
            conversationColumnMaxWidth * DexterMessageMetrics.regularMaxWidthRatio,
            DexterMessageMetrics.assistantBubbleAbsoluteMaxWidth
        )

        return HStack(alignment: .top, spacing: DexterMessageMetrics.avatarToBubbleGap) {
            if streamingText.isEmpty && showsThinkingBeforeTokens {
                DexterConversationThinkingIndicator(profile: profile, characterState: liveCharacterState)
            } else {
                DexterAvatar(
                    profile: profile,
                    size: DexterAvatarSize.md,
                    characterState: liveCharacterState,
                    animationEnabled: true
                )
                .padding(.top, 2)

                DexterMessageBubble(
                    text: streamingDisplayText,
                    isError: companionManager.dexterChatErrorMessage != nil,
                    showsTail: true,
                    maxWidth: bubbleMaxWidth
                )
            }

            Spacer(minLength: 48)
        }
    }

    @ViewBuilder
    private var confirmationOverlay: some View {
        if let confirmation = companionManager.actionConfirmationPresentation {
            DexterActionConfirmationView(
                presentation: confirmation,
                onCancel: { companionManager.cancelPendingActionConfirmation() },
                onAllow: { companionManager.approvePendingActionConfirmation() }
            )
            .padding(DexterMetrics.space20)
        }
    }

    @ViewBuilder
    private var taskStatusBanner: some View {
        if let headline = DexterPanelPresentation.taskStatusHeadline(for: companionManager.panelActiveWorkflowTask),
           let detail = DexterPanelPresentation.taskStatusDetail(for: companionManager.panelActiveWorkflowTask) {
            DexterTaskStatusCard(headline: headline, detail: detail, presentation: .companionInline)
        }
    }

    private var resolvedConversationProfile: DexterProfile? {
        switch companionManager.homeWorkspacePresentation {
        case .dashboard:
            return companionManager.dexterProfileStore.activeProfile
        case .dexterWorkspace(let profileId):
            return companionManager.dexterProfileStore.profile(withId: profileId)
        }
    }

    private var fallbackProfile: DexterProfile {
        if let resolvedConversationProfile {
            return resolvedConversationProfile
        }
        if let firstProfile = companionManager.dexterProfileStore.profiles.first {
            return firstProfile
        }
        return DexterProfile(
            id: DexterSeedProfileIdentifier.personal,
            name: "Dexter",
            description: DexterProductCopy.tagline,
            avatar: DexterProfileAvatar(symbolName: "sparkles"),
            colorHex: "#34D399",
            purpose: DexterProductCopy.tagline,
            memoryScope: .isolated,
            conversationID: UUID(),
            workspace: .empty,
            connectedIntegrations: [],
            enabledSkills: [],
            workSuggestions: [],
            permissions: .defaultPermissions,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private var conversationColumnMaxWidth: CGFloat {
        DexterConversationLayout.chatColumnMaxWidth
    }

    private var messageGroups: [DexterConversationMessageGroup] {
        DexterConversationMessageGrouper.makeGroups(from: companionManager.dexterChatMessages)
    }

    private var activeWorkspaceTitle: String {
        switch companionManager.homeWorkspacePresentation {
        case .dashboard:
            return "Dexter"
        case .dexterWorkspace(let profileId):
            return companionManager.dexterProfileStore.profile(withId: profileId)?.name ?? "Dexter"
        }
    }

    private var activeWorkspaceSubtitle: String {
        switch companionManager.homeWorkspacePresentation {
        case .dashboard:
            return "Personal workspace"
        case .dexterWorkspace(let profileId):
            if let fileWorkspace = companionManager.dexterFileWorkspaceStore.workspace(forProfileId: profileId),
               fileWorkspace.hasAnyLocation {
                return "● \(fileWorkspace.name)"
            }
            return companionManager.dexterProfileStore.profile(withId: profileId)?.purpose ?? DexterProductCopy.tagline
        }
    }

    private var showsConversationEmptyState: Bool {
        companionManager.dexterChatMessages.isEmpty
            && companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty
            && companionManager.voiceInteractionState != .thinking
            && companionManager.activePointInvokeSession == nil
    }

    private var shouldShowStreamingRow: Bool {
        companionManager.voiceInteractionState == .thinking
            || companionManager.voiceInteractionState == .speaking
            || !companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty
    }

    private var showsThinkingBeforeTokens: Bool {
        companionManager.voiceInteractionState == .thinking
            && companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty
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
        return ""
    }

    private var showsExecutionProgress: Bool {
        executionProgressTracker.shouldShowInConversation
            && isExecutionPhaseActive
    }

    private var isExecutionPhaseActive: Bool {
        switch companionManager.dexterRuntimeUIStateStore.currentState {
        case .planning, .waitingPermission, .acting, .verifying:
            return true
        default:
            return false
        }
    }

    private var executionProgressHeadline: String {
        switch companionManager.dexterRuntimeUIStateStore.currentState {
        case .verifying:
            return "Checking the result…"
        case .waitingPermission:
            return "Waiting for your approval…"
        default:
            return "Working on it…"
        }
    }

    private var pointInvokePromptSuggestions: some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space10) {
            Text("Try asking")
                .font(DexterTypography.section())
                .foregroundColor(DexterColors.textTertiary)
            DexterQuickPromptChip(title: "What is this?") {
                companionManager.submitTextMessageToDexter("What is this?")
            }
            DexterQuickPromptChip(title: "How do I use it?") {
                companionManager.submitTextMessageToDexter("How do I use it?")
            }
            DexterQuickPromptChip(title: "Click it.") {
                companionManager.submitTextMessageToDexter("Click it.")
            }
        }
        .frame(maxWidth: 420)
    }

    private func ingestExecutionProgress(statusDetail: String) {
        let snapshot = companionManager.dexterRuntimeUIStateStore.activeExecutionSnapshot
        executionProgressTracker.ingest(
            runtimeState: companionManager.dexterRuntimeUIStateStore.currentState,
            statusDetail: statusDetail,
            progressSummary: snapshot?.progressSummary
        )
    }

    private func scrollToBottomIfPinned(proxy: ScrollViewProxy) {
        guard stickToBottom else { return }
        withAnimation(DexterAnimation.gentleEase) {
            if shouldShowStreamingRow {
                proxy.scrollTo("streaming-assistant", anchor: .bottom)
            } else {
                proxy.scrollTo(bottomAnchorIdentifier, anchor: .bottom)
            }
        }
    }

    private func characterState(for group: DexterConversationMessageGroup) -> DexterCharacterState {
        guard group.role == .assistant,
              group.messages.contains(where: { $0.id == companionManager.dexterChatMessages.last?.id }),
              resolvedConversationProfile != nil else {
            return .idle
        }
        return liveCharacterState
    }

    private func shouldAnimateCharacter(for group: DexterConversationMessageGroup) -> Bool {
        guard group.role == .assistant else { return false }
        guard let activeProfile = resolvedConversationProfile else { return false }
        guard group.messages.contains(where: { $0.id == companionManager.dexterChatMessages.last?.id }) else {
            return false
        }
        return liveCharacterState != .idle && liveCharacterState != .sleeping
    }

    private func canDeleteChatMessage(_ message: DexterChatMessage) -> Bool {
        if !companionManager.dexterVoiceCoordinator.streamingResponseText.isEmpty {
            return false
        }
        switch companionManager.voiceInteractionState {
        case .thinking, .speaking, .transcribing:
            return false
        default:
            return true
        }
    }

    private func retryLastUserTurn() {
        guard let lastUserMessage = companionManager.dexterChatMessages.last(where: { $0.role == .user }) else {
            return
        }
        stickToBottom = true
        companionManager.submitTextMessageToDexter(lastUserMessage.text)
    }
}

extension DexterHomeWindowLayoutMode {
    var menuTitle: String {
        switch self {
        case .compact: return "Compact window"
        case .normal: return "Normal window"
        case .expanded: return "Expanded window"
        }
    }
}
