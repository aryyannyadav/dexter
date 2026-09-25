//
//  DexterAppearanceSettingsStore.swift
//  leanring-buddy
//

import Combine
import SwiftUI

enum DexterAppearanceMode: String, CaseIterable, Identifiable {
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum DexterProductAccentOption: String, CaseIterable, Identifiable {
    case dexterCyan = "dexter_cyan"
    case dexterOrange = "dexter_orange"
    case pastelPink = "pastel_pink"
    case lavender = "lavender"
    case blue = "blue"
    case mint = "mint"
    case coral = "coral"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dexterCyan: return "Dexter Cyan"
        case .dexterOrange: return "Dexter Orange"
        case .pastelPink: return "Pastel Pink"
        case .lavender: return "Lavender"
        case .blue: return "Blue"
        case .mint: return "Mint"
        case .coral: return "Coral"
        }
    }

    var accentHex: String {
        switch self {
        case .dexterCyan: return "#22D3EE"
        case .dexterOrange: return "#FF8A4C"
        case .pastelPink: return "#F2B5C6"
        case .lavender: return "#B8A4FF"
        case .blue: return "#38BDF8"
        case .mint: return "#6EE7B7"
        case .coral: return "#FF8F8F"
        }
    }

    var swatchColor: Color { Color(hex: accentHex) }
}

@MainActor
final class DexterAppearanceSettingsStore: ObservableObject {
    static let shared = DexterAppearanceSettingsStore()

    /// Updated synchronously for `DexterColors` accessors.
    nonisolated(unsafe) static var accentHexForRendering: String = "#22D3EE"

    @Published var appearanceMode: DexterAppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: appearanceModeKey)
        }
    }

    @Published var selectedProductAccent: DexterProductAccentOption {
        didSet {
            UserDefaults.standard.set(selectedProductAccent.rawValue, forKey: productAccentKey)
            Self.accentHexForRendering = selectedProductAccent.accentHex
        }
    }

    private let appearanceModeKey = "dexter.appearance.mode"
    private let productAccentKey = "dexter.appearance.productAccent"

    private init() {
        let storedMode = UserDefaults.standard.string(forKey: appearanceModeKey) ?? DexterAppearanceMode.dark.rawValue
        appearanceMode = DexterAppearanceMode(rawValue: storedMode) ?? .dark

        let storedAccent = UserDefaults.standard.string(forKey: productAccentKey) ?? DexterProductAccentOption.dexterCyan.rawValue
        selectedProductAccent = DexterProductAccentOption(rawValue: storedAccent) ?? .dexterCyan
        Self.accentHexForRendering = selectedProductAccent.accentHex
    }

    var productAccentColor: Color {
        selectedProductAccent.swatchColor
    }
}
