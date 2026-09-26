//
//  DexterSuggestionAvatarView.swift
//  leanring-buddy
//

import SwiftUI

/// Optional persona tile for surfaces that explicitly need a tinted container (not chat/sidebar).
enum DexterCharacterAvatarPlacement {
    case sidebarDexterRow
    case workspaceHeader
    case message
    case suggestionCard

    var containerSize: CGFloat {
        switch self {
        case .sidebarDexterRow: return 48
        case .workspaceHeader: return 40
        case .message: return 34
        case .suggestionCard: return 64
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .sidebarDexterRow: return 13
        case .workspaceHeader: return 11
        case .message: return 9
        case .suggestionCard: return 14
        }
    }

    var artworkMagnification: CGFloat {
        switch self {
        case .sidebarDexterRow: return 1.24
        case .workspaceHeader: return 1.22
        case .message: return 1.26
        case .suggestionCard: return 1.20
        }
    }

    var showsPersonaBackground: Bool {
        switch self {
        case .message: return false
        default: return true
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .message: return 0.10
        case .sidebarDexterRow: return 0.18
        case .workspaceHeader: return 0.16
        case .suggestionCard: return 0.20
        }
    }
}

struct DexterSuggestionAvatarView: View {
    let profile: DexterProfile
    var characterState: DexterCharacterState = .idle
    var placement: DexterCharacterAvatarPlacement = .sidebarDexterRow
    var containerSize: CGFloat?
    var isHovered: Bool = false
    var animationEnabled: Bool = false

    private var resolvedContainerSize: CGFloat {
        containerSize ?? placement.containerSize
    }

    private var characterRenderSize: CGFloat {
        resolvedContainerSize * 0.92
    }

    var body: some View {
        ZStack {
            if placement.showsPersonaBackground {
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(
                        DexterPersonaAccentCatalog.surfaceTint(for: profile)
                            .opacity(placement.backgroundOpacity)
                    )
            } else {
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(placement.backgroundOpacity))
            }

            if let definition = resolvedDefinition {
                DexterCharacterView(
                    definition: definition,
                    appearance: profile.characterAppearance,
                    state: characterState,
                    size: .custom(characterRenderSize),
                    presentationMode: .stage,
                    artworkMagnification: placement.artworkMagnification,
                    animationEnabled: animationEnabled,
                    profileNameForAccessibility: nil
                )
            }
        }
        .frame(width: resolvedContainerSize, height: resolvedContainerSize)
        .clipShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
        .scaleEffect(isHovered && !DexterMotionPreferences.shouldReduceMotion ? 1.03 : 1)
        .animation(DexterSuggestionMotion.hoverEase, value: isHovered)
        .accessibilityHidden(true)
    }

    private var resolvedCornerRadius: CGFloat {
        if containerSize != nil {
            return max(9, resolvedContainerSize * 0.26)
        }
        return placement.cornerRadius
    }

    private var resolvedDefinition: DexterCharacterDefinition? {
        if let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
            return definition
        }
        return DexterCharacterCatalog.character(
            withID: DexterCharacterCatalog.defaultCharacterID(forProfileID: profile.id)
        )
    }
}
