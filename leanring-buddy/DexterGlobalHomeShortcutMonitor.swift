//
//  DexterGlobalHomeShortcutMonitor.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Opens the Dexter Home window and focuses chat (⌘⇧D).
@MainActor
final class DexterGlobalHomeShortcutMonitor {
    static let textModeShortcutDisplayText = "⌘⇧D"

    private var globalKeyMonitor: Any?

    func start() {
        guard globalKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  event.modifierFlags.contains(.shift),
                  !event.modifierFlags.contains(.option),
                  event.keyCode == 2 else {
                return
            }

            Task { @MainActor in
                NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
                NotificationCenter.default.post(name: .dexterHomeFocusChat, object: nil)
            }
        }
    }

    func stop() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }
}
