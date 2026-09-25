//
//  DexterHomeView.swift
//  leanring-buddy
//

import SwiftUI

/// Root layout for the Dexter Home window — permanent sidebar + main conversation column.
struct DexterHomeView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject private var appearanceSettings = DexterAppearanceSettingsStore.shared
    @State private var composerText: String = ""
    @State private var sidebarSection: DexterHomeSidebarSection = .chat
    @State private var isCreateDexterSheetPresented = false
    @State private var characterEditorProfile: DexterProfile?
    @State private var profileIdentitySheetItem: DexterProfileSheetPresentationItem?
    @State private var homeWindowWidth: CGFloat = 1100

    private var usesWideProfilePanel: Bool {
        homeWindowWidth >= 960
    }

    private var sidebarWidth: CGFloat {
        homeWindowWidth < 880
            ? DexterConversationLayout.sidebarWidthCompact
            : DexterConversationLayout.sidebarWidth
    }

    private var isCompactSidebar: Bool {
        homeWindowWidth < 880
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                DexterHomeSidebar(
                    companionManager: companionManager,
                    selectedSection: sidebarSection,
                    onSelectSection: { sidebarSection = $0 },
                    onCreateDexter: { isCreateDexterSheetPresented = true },
                    onEditCharacter: { profile in
                        characterEditorProfile = profile
                    },
                    onOpenProfile: { profileId in
                        profileIdentitySheetItem = DexterProfileSheetPresentationItem(profileId: profileId)
                    },
                    isCompact: isCompactSidebar
                )
                .frame(width: sidebarWidth)

                ZStack(alignment: .trailing) {
                    Group {
                        switch sidebarSection {
                        case .chat:
                            DexterHomeChatPane(
                                companionManager: companionManager,
                                composerText: $composerText,
                                onOpenProfile: { profileId in
                                    profileIdentitySheetItem = DexterProfileSheetPresentationItem(profileId: profileId)
                                }
                            )
                        case .suggestions:
                            DexterHomeSuggestionsView(companionManager: companionManager)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        }
                    }
                    .animation(DexterAnimation.standardSpring, value: sidebarSection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if usesWideProfilePanel, let profileItem = profileIdentitySheetItem {
                        profileDismissScrim
                        profileIdentityPanel(profileItem: profileItem)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .background(DexterColors.background)
            .onAppear {
                homeWindowWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                homeWindowWidth = newWidth
            }
            .onChange(of: companionManager.homeWorkspacePresentation) { _, presentation in
                guard profileIdentitySheetItem != nil else { return }
                if case .dexterWorkspace(let profileId) = presentation {
                    profileIdentitySheetItem = DexterProfileSheetPresentationItem(profileId: profileId)
                }
            }
        }
        .preferredColorScheme(appearanceSettings.appearanceMode.preferredColorScheme ?? .dark)
        .id(appearanceSettings.selectedProductAccent.rawValue)
        .onAppear {
            companionManager.pendingMainWindowDestination = .chat
            companionManager.runScreenCaptureCapabilityProbeIfNeeded()
            companionManager.dexterSuggestionStore.refreshSuggestionsFromAuthorizedContext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dexterHomeFocusChat)) { _ in
            sidebarSection = .chat
        }
        .sheet(isPresented: $companionManager.isDexterActivityBrowserPresented) {
            NavigationStack {
                DexterProfileActivityView(
                    companionManager: companionManager,
                    profileId: companionManager.dexterActivityBrowserProfileId,
                    showsDexterLabels: companionManager.dexterActivityBrowserProfileId == nil
                )
                .padding(DexterMetrics.space16)
                .navigationTitle("Activity")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            companionManager.isDexterActivityBrowserPresented = false
                        }
                    }
                }
            }
            .frame(minWidth: 520, minHeight: 560)
        }
        .onChange(of: companionManager.pendingUniversalCommandComposerText) { _, pendingText in
            guard let pendingText, !pendingText.isEmpty else { return }
            composerText = pendingText
            companionManager.pendingUniversalCommandComposerText = nil
        }
        .onChange(of: companionManager.pendingUniversalCommandProfileId) { _, profileId in
            guard let profileId else { return }
            profileIdentitySheetItem = DexterProfileSheetPresentationItem(profileId: profileId)
            companionManager.pendingUniversalCommandProfileId = nil
        }
        .background {
            Button("New chat") {
                companionManager.startNewDexterConversation()
            }
            .keyboardShortcut("n", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .sheet(isPresented: $isCreateDexterSheetPresented) {
            DexterCreateDexterProfileSheet(companionManager: companionManager)
        }
        .sheet(item: $characterEditorProfile) { profile in
            NavigationStack {
                DexterEditCharacterView(
                    profile: profile,
                    onSave: { savedAppearance in
                        companionManager.dexterProfileStore.updateCharacterAppearance(
                            profileId: profile.id,
                            appearance: savedAppearance
                        )
                        characterEditorProfile = nil
                    },
                    onCancel: {
                        characterEditorProfile = nil
                    }
                )
            }
        }
        .sheet(item: compactProfileSheetBinding) { profileItem in
            profileIdentityPanel(profileItem: profileItem)
        }
    }

    private var compactProfileSheetBinding: Binding<DexterProfileSheetPresentationItem?> {
        Binding(
            get: {
                guard !usesWideProfilePanel else { return nil }
                return profileIdentitySheetItem
            },
            set: { profileIdentitySheetItem = $0 }
        )
    }

    private var profileDismissScrim: some View {
        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                profileIdentitySheetItem = nil
            }
            .pointerCursor()
            .accessibilityLabel("Dismiss profile")
            .accessibilityAddTraits(.isButton)
    }

    private func profileIdentityPanel(profileItem: DexterProfileSheetPresentationItem) -> some View {
        DexterProfileIdentitySheet(
            companionManager: companionManager,
            profileId: profileItem.profileId,
            onChat: {
                sidebarSection = .chat
                companionManager.openDexterProfileWorkspace(profileId: profileItem.profileId)
            },
            onEditCharacter: { profile in
                characterEditorProfile = profile
            },
            onDismiss: {
                profileIdentitySheetItem = nil
            }
        )
        .frame(width: min(460, max(340, homeWindowWidth * 0.38)))
        .frame(maxHeight: .infinity)
        .background(DexterSurfaceColors.background)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DexterColors.borderSubtle)
                .frame(width: 1)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: -8, y: 0)
    }
}
