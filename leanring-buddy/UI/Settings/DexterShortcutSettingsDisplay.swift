//
//  DexterShortcutSettingsDisplay.swift
//

import Foundation

enum DexterShortcutSettingsDisplay {
    static var pushToTalkLabel: String {
        BuddyPushToTalkShortcut.pushToTalkDisplayText
    }

    static var pointInvokeLabel: String {
        DexterPointInvokeShortcut.displayText
    }
}
