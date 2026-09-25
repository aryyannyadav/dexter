//
//  DexterEditCharacterView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterEditCharacterView: View {
    let profile: DexterProfile
    let onSave: (DexterCharacterAppearance) -> Void
    let onCancel: () -> Void

    @State private var draftAppearance: DexterCharacterAppearance
    @State private var selectedCharacterID: String

    init(
        profile: DexterProfile,
        onSave: @escaping (DexterCharacterAppearance) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        _draftAppearance = State(initialValue: profile.characterAppearance)
        _selectedCharacterID = State(initialValue: profile.characterAppearance.characterID)
    }

    var body: some View {
        HStack(spacing: 0) {
            previewColumn
                .frame(maxWidth: .infinity)
                .background(DexterSurfaceColors.background)

            Divider()

            controlsColumn
                .frame(width: 360)
                .background(DexterSurfaceColors.secondaryBackground)
        }
        .frame(minWidth: 820, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancelEditing)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveEditing)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .navigationTitle("Edit character")
    }

    private var previewColumn: some View {
        VStack(spacing: DexterSpacing.xl) {
            Spacer()

            if let definition = selectedDefinition {
                DexterCharacterView(
                    definition: definition,
                    appearance: draftAppearance,
                    state: .idle,
                    size: .hero,
                    presentationMode: .full,
                    animationEnabled: true,
                    profileNameForAccessibility: profile.name
                )
            }

            VStack(spacing: DexterSpacing.xs) {
                Text(profile.name)
                    .font(DexterTypography.title())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                Text(profile.purpose)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterSurfaceColors.textSecondary)
            }

            Spacer()
        }
        .padding(DexterSpacing.xxl)
    }

    private var controlsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DexterSpacing.xl) {
                charactersSection
                if selectedDefinition?.supportedOptions.supportsAvatarBackground == true {
                    backgroundSection
                }
            }
            .padding(DexterSpacing.lg)
        }
    }

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            Text("CHARACTERS")
                .font(DexterTypography.section())
                .foregroundColor(DexterSurfaceColors.textMuted)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: DexterSpacing.sm)],
                spacing: DexterSpacing.sm
            ) {
                ForEach(DexterCharacterCatalog.coreCharacters) { character in
                    characterCard(character)
                }
            }
        }
    }

    private func characterCard(_ character: DexterCharacterDefinition) -> some View {
        let isSelected = selectedCharacterID == character.id
        return Button {
            selectedCharacterID = character.id
            draftAppearance.characterID = character.id
            draftAppearance.background = character.defaultAppearance.background
        } label: {
            VStack(spacing: DexterSpacing.sm) {
                DexterCharacterView(
                    definition: character,
                    appearance: character.defaultAppearance,
                    state: .idle,
                    size: .small,
                    presentationMode: .avatar,
                    animationEnabled: false
                )
                Text(character.displayName)
                    .font(DexterTypography.metadata())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .lineLimit(1)
            }
            .padding(DexterSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                    .fill(isSelected ? profile.accentColor.opacity(0.12) : DexterSurfaceColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                    .stroke(isSelected ? profile.accentColor.opacity(0.65) : DexterSurfaceColors.border, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(profile.accentColor)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            Text("AVATAR BACKGROUND")
                .font(DexterTypography.section())
                .foregroundColor(DexterSurfaceColors.textMuted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DexterSpacing.sm), count: 3), spacing: DexterSpacing.sm) {
                ForEach(DexterCharacterBackgroundStyle.allCases) { backgroundStyle in
                    let isSelected = draftAppearance.background == backgroundStyle
                    Button {
                        draftAppearance.background = backgroundStyle
                    } label: {
                        RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                            .fill(backgroundStyle.color)
                            .frame(height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                                    .stroke(isSelected ? profile.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                    .accessibilityLabel(backgroundStyle.displayName)
                }
            }
        }
    }

    private var selectedDefinition: DexterCharacterDefinition? {
        DexterCharacterCatalog.character(withID: selectedCharacterID)
    }

    private func saveEditing() {
        onSave(draftAppearance)
    }

    private func cancelEditing() {
        onCancel()
    }
}
