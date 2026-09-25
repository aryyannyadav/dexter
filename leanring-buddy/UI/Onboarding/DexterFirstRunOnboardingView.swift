//
//  DexterFirstRunOnboardingView.swift
//  leanring-buddy
//

import AVFoundation
import AppKit
import SwiftUI

struct DexterFirstRunOnboardingView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject private var onboardingStore: DexterFirstRunOnboardingStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        self.onboardingStore = companionManager.firstRunOnboardingStore
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 720

            ZStack {
                DexterColors.background
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        DexterPastelColors.lavender.opacity(0.12),
                        DexterColors.background.opacity(0)
                    ],
                    center: .top,
                    startRadius: 40,
                    endRadius: 420
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    progressHeader
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    if isCompact {
                        VStack(spacing: 20) {
                            characterPanel
                                .frame(maxWidth: .infinity)
                            stepContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.horizontal, 28)
                    } else {
                        HStack(alignment: .top, spacing: 32) {
                            characterPanel
                                .frame(width: 260)
                            stepContent
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.horizontal, 32)
                    }

                    footerActions
                        .padding(.horizontal, 32)
                        .padding(.bottom, 28)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .animation(reduceMotion ? nil : DexterAnimation.gentleEase, value: onboardingStore.currentStep)
        .onAppear {
            companionManager.prepareFirstRunOnboardingStep(onboardingStore.currentStep)
        }
        .onChange(of: onboardingStore.currentStep) { _, newStep in
            companionManager.prepareFirstRunOnboardingStep(newStep)
        }
        .sheet(isPresented: $onboardingStore.isCharacterCustomizePresented) {
            if let definition = selectedCharacterDefinition {
                DexterOnboardingCharacterCustomizeSheet(
                    profileName: onboardingStore.profileDraft.name,
                    definition: definition,
                    appearance: onboardingStore.profileDraft.characterAppearance,
                    onSave: { updatedAppearance in
                        onboardingStore.profileDraft.characterAppearance = updatedAppearance
                        onboardingStore.isCharacterCustomizePresented = false
                    },
                    onCancel: {
                        onboardingStore.isCharacterCustomizePresented = false
                    }
                )
            }
        }
    }

    private var selectedCharacterDefinition: DexterCharacterDefinition? {
        let characterID = onboardingStore.profileDraft.characterAppearance.characterID
        return DexterCharacterCatalog.character(withID: characterID)
            ?? DexterCharacterCatalog.character(withID: DexterCharacterCatalog.personalCharacterID)
    }

    private var characterState: DexterCharacterState {
        switch onboardingStore.currentStep {
        case .welcome, .ready:
            return .idle
        case .permissions:
            return .thinking
        default:
            return .idle
        }
    }

    @ViewBuilder
    private var characterPanel: some View {
        VStack(spacing: 12) {
            if let definition = selectedCharacterDefinition {
                DexterCharacterView(
                    definition: definition,
                    appearance: onboardingStore.profileDraft.characterAppearance,
                    state: characterState,
                    size: .hero,
                    presentationMode: .stage,
                    animationEnabled: !reduceMotion,
                    profileNameForAccessibility: onboardingStore.profileDraft.name
                )
                .accessibilityHidden(onboardingStore.currentStep == .welcome)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch onboardingStore.currentStep {
            case .welcome:
                DexterOnboardingWelcomeStep()
            case .purpose:
                DexterOnboardingPurposeStep(onboardingStore: onboardingStore)
            case .customPurpose:
                DexterOnboardingCustomPurposeStep(onboardingStore: onboardingStore)
            case .identity:
                DexterOnboardingIdentityStep(
                    onboardingStore: onboardingStore,
                    onCustomizeCharacter: { onboardingStore.isCharacterCustomizePresented = true }
                )
            case .workspace:
                DexterOnboardingWorkspaceStep(
                    companionManager: companionManager,
                    onboardingStore: onboardingStore
                )
            case .permissions:
                DexterOnboardingPermissionsStep(companionManager: companionManager)
            case .ready:
                DexterOnboardingReadyStep(
                    companionManager: companionManager,
                    onboardingStore: onboardingStore
                )
            }
        }
        .id(onboardingStore.currentStep)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 10)),
            removal: .opacity
        ))
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            if onboardingStore.currentStep != .welcome {
                HStack(spacing: 8) {
                    ForEach(1...DexterFirstRunOnboardingStep.progressGroupCount, id: \.self) { groupIndex in
                        Capsule()
                            .fill(groupIndex <= onboardingStore.currentStep.progressGroupIndex
                                ? DexterPastelColors.lavender
                                : DexterColors.borderSubtle)
                            .frame(height: 3)
                    }
                }
                HStack {
                    ForEach(Array(DexterFirstRunOnboardingStep.progressGroupLabels.enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(DexterTypography.caption())
                            .foregroundColor(
                                index + 1 <= onboardingStore.currentStep.progressGroupIndex
                                    ? DexterColors.textSecondary
                                    : DexterColors.textTertiary
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(onboardingStore.currentStep == .welcome
            ? "Welcome to Dexter"
            : "Onboarding step \(onboardingStore.currentStep.progressGroupIndex) of \(DexterFirstRunOnboardingStep.progressGroupCount)")
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            if onboardingStore.currentStep != .welcome {
                DexterSecondaryButton(title: "Back") {
                    withAnimation(reduceMotion ? nil : DexterAnimation.gentleEase) {
                        onboardingStore.goBackToPreviousStep()
                    }
                }
            }

            Spacer()

            if onboardingStore.currentStep == .welcome {
                Button("Skip for now") {
                    companionManager.skipFirstRunProductOnboardingAndOpenHome()
                }
                .buttonStyle(.plain)
                .foregroundColor(DexterColors.textSecondary)
                .pointerCursor()

                DexterButton(title: "Get started", isFullWidth: false) {
                    withAnimation(reduceMotion ? nil : DexterAnimation.gentleEase) {
                        onboardingStore.advanceToNextStep()
                    }
                }
            } else if onboardingStore.currentStep == .ready {
                DexterButton(title: "Start using Dexter", isFullWidth: false, action: finishOnboarding)
            } else {
                DexterButton(
                    title: primaryButtonTitle,
                    isFullWidth: false,
                    action: primaryAction
                )
                .disabled(!onboardingStore.canAdvanceFromCurrentStep)
                .opacity(onboardingStore.canAdvanceFromCurrentStep ? 1 : 0.45)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch onboardingStore.currentStep {
        case .customPurpose:
            return "Continue"
        case .identity:
            return "Continue"
        case .workspace:
            return "Continue"
        case .permissions:
            return "Continue"
        case .purpose:
            return "Continue"
        default:
            return "Continue"
        }
    }

    private func primaryAction() {
        if onboardingStore.currentStep == .customPurpose {
            onboardingStore.applyCustomPurposeDraft()
        }
        withAnimation(reduceMotion ? nil : DexterAnimation.gentleEase) {
            onboardingStore.advanceToNextStep()
        }
    }

    private func finishOnboarding() {
        companionManager.completeFirstRunProductOnboardingAndOpenHome()
    }
}

// MARK: - Steps

private struct DexterOnboardingWelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MEET DEXTER")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Your computer finally understands you.")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textSecondary)

            Text("Dexter understands what you're doing, helps you learn, and can act on your computer when you ask.")
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Dexter only uses the access you give it. Screen context is captured when needed for an interaction.")
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }
}

private struct DexterOnboardingPurposeStep: View {
    @ObservedObject var onboardingStore: DexterFirstRunOnboardingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT DO YOU WANT DEXTER TO HELP WITH?")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(DexterOnboardingArchetype.selectableArchetypes) { archetype in
                        DexterOnboardingArchetypeCard(
                            title: archetype.title,
                            subtitle: archetype.subtitle,
                            isSelected: onboardingStore.profileDraft.archetype == archetype
                        ) {
                            onboardingStore.selectArchetype(archetype)
                        }
                    }

                    DexterOnboardingArchetypeCard(
                        title: "Create your own",
                        subtitle: "Describe what you want Dexter to help with.",
                        isSelected: onboardingStore.profileDraft.archetype == .custom
                    ) {
                        onboardingStore.jumpToPurposeWithCustomOption()
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct DexterOnboardingCustomPurposeStep: View {
    @ObservedObject var onboardingStore: DexterFirstRunOnboardingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CREATE YOUR DEXTER")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Tell Dexter what you want help with.")
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)

            TextField(
                "I want a Dexter that helps me build my startup.",
                text: $onboardingStore.profileDraft.customPurposeText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3...6)
            .padding(DexterMetrics.space12)
            .background(DexterColors.inputBackground)
            .cornerRadius(DexterMetrics.radiusMedium)

            Spacer(minLength: 0)
        }
    }
}

private struct DexterOnboardingIdentityStep: View {
    @ObservedObject var onboardingStore: DexterFirstRunOnboardingStore
    let onCustomizeCharacter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NAME YOUR DEXTER")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            TextField("Name", text: $onboardingStore.profileDraft.name)
                .textFieldStyle(.plain)
                .padding(DexterMetrics.space12)
                .background(DexterColors.inputBackground)
                .cornerRadius(DexterMetrics.radiusMedium)

            TextField("Role", text: $onboardingStore.profileDraft.roleLine)
                .textFieldStyle(.plain)
                .padding(DexterMetrics.space12)
                .background(DexterColors.inputBackground)
                .cornerRadius(DexterMetrics.radiusMedium)

            HStack(spacing: 12) {
                DexterSecondaryButton(title: "Customize", action: onCustomizeCharacter)
                DexterSecondaryButton(title: "Keep default") { }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct DexterOnboardingWorkspaceStep: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var onboardingStore: DexterFirstRunOnboardingStore

    private var workspacePrompt: String {
        onboardingStore.profileDraft.archetype?.workspacePrompt
            ?? "Choose a folder for your project, notes, or coursework."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GIVE DEXTER A WORKSPACE?")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(workspacePrompt)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                DexterButton(title: "Choose workspace", isFullWidth: false) {
                    let pickedURLs = companionManager.dexterFileWorkspaceService.pickWorkspaceURLs()
                    onboardingStore.profileDraft.workspaceURLs = pickedURLs
                    if let firstURL = pickedURLs.first {
                        onboardingStore.profileDraft.workspaceName =
                            DexterFileWorkspaceBookmarkAccess.suggestedWorkspaceName(for: firstURL)
                        onboardingStore.profileDraft.workspaceDisplayLabel = pickedURLs
                            .map { DexterFileWorkspaceBookmarkAccess.tildeDisplayPath(for: $0.path) }
                            .joined(separator: ", ")
                    }
                    onboardingStore.profileDraft.didSkipWorkspace = pickedURLs.isEmpty
                    DexterAnalytics.trackOnboardingWorkspaceSelected(didSelectWorkspace: !pickedURLs.isEmpty)
                }
                DexterSecondaryButton(title: "Skip for now") {
                    onboardingStore.profileDraft.workspaceURLs = []
                    onboardingStore.profileDraft.didSkipWorkspace = true
                    DexterAnalytics.trackOnboardingWorkspaceSelected(didSelectWorkspace: false)
                }
            }

            if !onboardingStore.profileDraft.workspaceDisplayLabel.isEmpty {
                Text(onboardingStore.profileDraft.workspaceDisplayLabel)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct DexterOnboardingPermissionsStep: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CONNECT WHEN YOU'RE READY")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text("Grant access only for what you want to use now. You can change this anytime in Settings.")
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            DexterOnboardingPermissionCard(
                title: "Screen context",
                detail: "Dexter can look at your screen when you ask for help.",
                isGranted: companionManager.hasScreenRecordingPermission,
                onAllow: { companionManager.requestScreenRecordingPermissionFromPanel() },
                onNotNow: {}
            )

            DexterOnboardingPermissionCard(
                title: "Microphone",
                detail: "Voice works when you hold your push-to-talk shortcut.",
                isGranted: companionManager.hasMicrophonePermission,
                onAllow: openMicrophoneSettings,
                onNotNow: {}
            )

            DexterOnboardingPermissionCard(
                title: "Computer control",
                detail: "Dexter can click and control apps when you explicitly ask.",
                isGranted: companionManager.hasAccessibilityPermission,
                onAllow: { companionManager.requestAccessibilityPermissionFromPanel() },
                onNotNow: {}
            )

            Spacer(minLength: 0)
        }
        .onAppear {
            companionManager.refreshAllPermissions(caller: "onboardingPermissions", emitVerbosePermissionDiagnostics: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            companionManager.refreshAllPermissions(caller: "onboardingPermissionsReturn", emitVerbosePermissionDiagnostics: false)
        }
    }

    private func openMicrophoneSettings() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    DexterAnalytics.trackOnboardingPermissionResult(permission: "microphone", granted: granted)
                    companionManager.refreshAllPermissions(caller: "onboardingMic", emitVerbosePermissionDiagnostics: false)
                }
            }
        } else if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(settingsURL)
        }
    }
}

private struct DexterOnboardingReadyStep: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var onboardingStore: DexterFirstRunOnboardingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR DEXTER IS READY")
                .font(DexterTypography.title())
                .foregroundColor(DexterColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(onboardingStore.profileDraft.name)
                .font(DexterTypography.display())
                .foregroundColor(DexterColors.textPrimary)

            Text(onboardingStore.profileDraft.roleLine)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                capabilityRow("Chat", enabled: true)
                capabilityRow("Screen understanding", enabled: companionManager.hasScreenRecordingPermission)
                capabilityRow("Computer control", enabled: companionManager.hasAccessibilityPermission)
                capabilityRow(
                    "Workspace",
                    enabled: !onboardingStore.profileDraft.workspaceURLs.isEmpty
                        && !onboardingStore.profileDraft.didSkipWorkspace
                )
            }
            .padding(.top, 8)

            if let suggestion = onboardingStore.profileDraft.archetype?.firstRunSuggestionPrompt {
                Text("Try: “\(suggestion)”")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
    }

    private func capabilityRow(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(enabled ? DexterColors.success : DexterColors.textTertiary)
            Text(title)
                .font(DexterTypography.body())
                .foregroundColor(enabled ? DexterColors.textPrimary : DexterColors.textTertiary)
        }
    }
}

// MARK: - Components

private struct DexterOnboardingArchetypeCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DexterTypography.bodyMedium())
                        .foregroundColor(DexterColors.textPrimary)
                    Text(subtitle)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DexterPastelColors.lavender)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                    .fill(isSelected ? DexterPastelColors.lavender.opacity(0.1) : DexterColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                    .stroke(isSelected ? DexterPastelColors.lavender.opacity(0.45) : DexterColors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

private struct DexterOnboardingPermissionCard: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
            Text(detail)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                if isGranted {
                    Label("Ready", systemImage: "checkmark.seal.fill")
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.success)
                } else {
                    Button("Allow", action: onAllow)
                        .buttonStyle(.borderedProminent)
                        .pointerCursor()
                    Button("Not now", action: onNotNow)
                        .buttonStyle(.plain)
                        .foregroundColor(DexterColors.textSecondary)
                        .pointerCursor()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                .fill(DexterColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                .stroke(DexterColors.borderSubtle, lineWidth: 1)
        )
    }
}

private struct DexterOnboardingCharacterCustomizeSheet: View {
    let profileName: String
    let definition: DexterCharacterDefinition
    let appearance: DexterCharacterAppearance
    let onSave: (DexterCharacterAppearance) -> Void
    let onCancel: () -> Void

    @State private var draftProfile: DexterProfile

    init(
        profileName: String,
        definition: DexterCharacterDefinition,
        appearance: DexterCharacterAppearance,
        onSave: @escaping (DexterCharacterAppearance) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.profileName = profileName
        self.definition = definition
        self.appearance = appearance
        self.onSave = onSave
        self.onCancel = onCancel
        _draftProfile = State(initialValue: DexterProfile(
            id: UUID(),
            name: profileName,
            description: "",
            avatar: DexterProfileAvatar(symbolName: "sparkles"),
            colorHex: "#5CE1E6",
            purpose: "",
            memoryScope: .isolated,
            conversationID: UUID(),
            workspace: .empty,
            connectedIntegrations: [],
            enabledSkills: [],
            workSuggestions: [],
            permissions: .defaultPermissions,
            characterAppearance: appearance,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }

    var body: some View {
        DexterEditCharacterView(
            profile: draftProfile,
            onSave: { savedAppearance in
                onSave(savedAppearance)
            },
            onCancel: onCancel
        )
    }
}
