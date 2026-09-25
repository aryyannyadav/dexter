//
//  DexterMotionPreferences.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterMotionPreferences {
    static var shouldReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}
