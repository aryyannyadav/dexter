//
//  DexterUniversalCommandShortcutMonitor.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Global + local ⌘K monitor (same pattern as `DexterGlobalHomeShortcutMonitor`).
@MainActor
final class DexterUniversalCommandShortcutMonitor {
    static let shortcutDisplayText = "⌘K"
    private static let commandKeyKeyCode: UInt16 = 40

    var onToggle: (() -> Void)?

    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    func start() {
        guard globalKeyMonitor == nil, localKeyMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isUniversalCommandShortcut(event) else { return }
            Task { @MainActor in
                self?.onToggle?()
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isUniversalCommandShortcut(event) else { return event }
            Task { @MainActor in
                self?.onToggle?()
            }
            return nil
        }
    }

    func stop() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private static func isUniversalCommandShortcut(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
            && !event.modifierFlags.contains(.option)
            && !event.modifierFlags.contains(.control)
            && event.keyCode == commandKeyKeyCode
    }
}
