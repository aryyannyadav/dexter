//
//  DexterShortcutSettingsStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterShortcutSettingsStore: ObservableObject {
    static let shared = DexterShortcutSettingsStore()

    @Published var pushToTalkShortcutOption: BuddyPushToTalkShortcut.ShortcutOption {
        didSet {
            UserDefaults.standard.set(pushToTalkShortcutOption.storageKey, forKey: pushToTalkOptionKey)
        }
    }

    private let pushToTalkOptionKey = "dexterPushToTalkShortcutOption"

    private init() {
        let storedKey = UserDefaults.standard.string(forKey: pushToTalkOptionKey)
        pushToTalkShortcutOption = BuddyPushToTalkShortcut.ShortcutOption.fromStorageKey(storedKey)
            ?? .controlOption
    }

    func resetToDefaults() {
        pushToTalkShortcutOption = .controlOption
    }
}

extension BuddyPushToTalkShortcut.ShortcutOption {
    var storageKey: String {
        switch self {
        case .shiftFunction: return "shiftFunction"
        case .controlOption: return "controlOption"
        case .shiftControl: return "shiftControl"
        case .controlOptionSpace: return "controlOptionSpace"
        case .shiftControlSpace: return "shiftControlSpace"
        }
    }

    static func fromStorageKey(_ storageKey: String?) -> BuddyPushToTalkShortcut.ShortcutOption? {
        guard let storageKey else { return nil }
        switch storageKey {
        case "shiftFunction": return .shiftFunction
        case "controlOption": return .controlOption
        case "shiftControl": return .shiftControl
        case "controlOptionSpace": return .controlOptionSpace
        case "shiftControlSpace": return .shiftControlSpace
        default: return nil
        }
    }
}
