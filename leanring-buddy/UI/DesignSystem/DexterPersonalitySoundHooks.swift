//
//  DexterPersonalitySoundHooks.swift
//  leanring-buddy
//
//  Optional macOS system sounds — no bundled audio files.
//

import AppKit
import Foundation

enum DexterPersonalitySoundEvent: Equatable {
    case taskStarted
    case permissionRequested
    case taskCompleted
    case error
    case suggestion
}

enum DexterPersonalitySoundHooks {
    private static let enabledUserDefaultsKey = "dexterPersonalitySoundsEnabled"

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledUserDefaultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledUserDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledUserDefaultsKey)
        }
    }

    static func play(_ event: DexterPersonalitySoundEvent) {
        guard isEnabled else { return }
        guard let soundName = systemSoundName(for: event) else { return }
        guard let sound = NSSound(named: NSSound.Name(soundName)) else { return }
        sound.volume = volume(for: event)
        sound.play()
    }

    private static func systemSoundName(for event: DexterPersonalitySoundEvent) -> String? {
        switch event {
        case .taskStarted:
            return "Tink"
        case .permissionRequested:
            return "Pop"
        case .taskCompleted:
            return "Glass"
        case .error:
            return "Basso"
        case .suggestion:
            return "Submarine"
        }
    }

    private static func volume(for event: DexterPersonalitySoundEvent) -> Float {
        switch event {
        case .taskStarted, .suggestion:
            return 0.35
        case .permissionRequested:
            return 0.45
        case .taskCompleted:
            return 0.4
        case .error:
            return 0.5
        }
    }
}
