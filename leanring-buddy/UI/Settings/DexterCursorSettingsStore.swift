//
//  DexterCursorSettingsStore.swift
//  leanring-buddy
//

import Combine
import SwiftUI

enum DexterCursorStyleOption: String, CaseIterable, Identifiable {
    case classic
    case spongeBob = "sponge_bob"
    case patrickStar = "patrick_star"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .spongeBob: return "SpongeBob"
        case .patrickStar: return "Patrick Star"
        }
    }
}

enum DexterCursorSizeOption: String, CaseIterable, Identifiable {
    case small
    case `default`
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .default: return "Default"
        case .large: return "Large"
        }
    }

    var scaleMultiplier: CGFloat {
        switch self {
        case .small: return 0.85
        case .default: return 1.0
        case .large: return 1.2
        }
    }
}

enum DexterCursorAccentColorOption: String, CaseIterable, Identifiable {
    case red
    case blue
    case yellow
    case green
    case pastelPink = "pastel_pink"
    case companionLavender = "companion_lavender"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .red: return "Red"
        case .blue: return "Companion Sky"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .pastelPink: return "Pastel Pink"
        case .companionLavender: return "Companion Lavender"
        }
    }

    var swatchColor: Color {
        Color(hex: overlayTintHex)
    }

    var overlayTintHex: String {
        switch self {
        case .red: return "#FF4D4F"
        case .blue: return "#93C5FD"
        case .yellow: return "#F5C542"
        case .green: return "#3DDC84"
        case .pastelPink: return "#F2B5C6"
        case .companionLavender: return "#C4B5FD"
        }
    }
}

@MainActor
final class DexterCursorSettingsStore: ObservableObject {
    static let shared = DexterCursorSettingsStore()

    @Published var selectedCursorStyle: DexterCursorStyleOption {
        didSet { UserDefaults.standard.set(selectedCursorStyle.rawValue, forKey: cursorStyleKey) }
    }

    @Published var selectedAccentColor: DexterCursorAccentColorOption {
        didSet { UserDefaults.standard.set(selectedAccentColor.rawValue, forKey: accentColorKey) }
    }

    @Published var isDockCursorEnabled: Bool {
        didSet { UserDefaults.standard.set(isDockCursorEnabled, forKey: dockCursorKey) }
    }

    @Published var cursorSizeOption: DexterCursorSizeOption {
        didSet { UserDefaults.standard.set(cursorSizeOption.rawValue, forKey: cursorSizeKey) }
    }

    var sizeScaleMultiplier: CGFloat {
        cursorSizeOption.scaleMultiplier
    }

    private let cursorStyleKey = "dexterCursorStyleOption"
    private let accentColorKey = "dexterCursorAccentColorOption"
    private let dockCursorKey = "dexterDockCursorEnabled"
    private let cursorSizeKey = "dexterCursorSizeOption"

    private init() {
        let storedStyle = UserDefaults.standard.string(forKey: cursorStyleKey) ?? DexterCursorStyleOption.classic.rawValue
        selectedCursorStyle = DexterCursorStyleOption(rawValue: storedStyle) ?? .classic

        let storedColor = UserDefaults.standard.string(forKey: accentColorKey)
            ?? DexterCursorAccentColorOption.companionLavender.rawValue
        selectedAccentColor = DexterCursorAccentColorOption(rawValue: storedColor) ?? .companionLavender
        isDockCursorEnabled = UserDefaults.standard.object(forKey: dockCursorKey) as? Bool ?? false

        let storedSize = UserDefaults.standard.string(forKey: cursorSizeKey) ?? DexterCursorSizeOption.default.rawValue
        cursorSizeOption = DexterCursorSizeOption(rawValue: storedSize) ?? .default
    }
}
