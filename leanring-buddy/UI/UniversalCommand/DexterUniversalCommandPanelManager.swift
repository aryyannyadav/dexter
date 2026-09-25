//
//  DexterUniversalCommandPanelManager.swift
//  leanring-buddy
//

import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let dexterToggleUniversalCommand = Notification.Name("dexterToggleUniversalCommand")
}

final class DexterKeyableCommandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class DexterUniversalCommandPanelState: ObservableObject {
    @Published var query: String = ""
    @Published var sections: [DexterCommandResultSection] = []
    @Published var selectedFlatIndex: Int = 0

    let maxContentHeight: CGFloat = 460

    var flatResults: [DexterCommandResult] {
        sections.flatMap(\.results)
    }

    func refreshSections(companionManager: CompanionManager) {
        let context = companionManager.universalCommandSearchContext()
        sections = DexterSearchService.search(
            query: query,
            companionManager: companionManager,
            searchContext: context,
            activeSuggestions: companionManager.dexterSuggestionStore.activeSuggestions
        )
        if selectedFlatIndex >= flatResults.count {
            selectedFlatIndex = 0
        }
    }

    func selectFlatIndex(_ index: Int) {
        guard !flatResults.isEmpty else {
            selectedFlatIndex = 0
            return
        }
        selectedFlatIndex = max(0, min(index, flatResults.count - 1))
    }

    func moveSelectionUp() {
        selectFlatIndex(selectedFlatIndex - 1)
    }

    func moveSelectionDown() {
        selectFlatIndex(selectedFlatIndex + 1)
    }

    var onPerformResult: ((DexterCommandResult, Bool) -> Void)?
}

@MainActor
final class DexterUniversalCommandPanelManager {
    private var commandPanel: DexterKeyableCommandPanel?
    private let panelState = DexterUniversalCommandPanelState()
    private let shortcutMonitor = DexterUniversalCommandShortcutMonitor()
    private var keyboardMonitor: Any?

    private weak var companionManager: CompanionManager?
    private weak var settingsRouter: DexterSettingsRouter?

    var isVisible: Bool {
        commandPanel?.isVisible == true
    }

    func install(companionManager: CompanionManager, settingsRouter: DexterSettingsRouter) {
        self.companionManager = companionManager
        self.settingsRouter = settingsRouter

        panelState.onPerformResult = { [weak self] result, useSecondary in
            self?.executeResult(result, useSecondary: useSecondary)
        }

        shortcutMonitor.onToggle = { [weak self] in
            self?.toggle()
        }
        shortcutMonitor.start()

        NotificationCenter.default.addObserver(
            forName: .dexterToggleUniversalCommand,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.toggle()
            }
        }
    }

    func toggle() {
        if isVisible {
            dismiss()
        } else {
            present()
        }
    }

    func present() {
        guard let companionManager, let settingsRouter else { return }

        if commandPanel == nil {
            let hostingView = NSHostingView(
                rootView: DexterUniversalCommandView(
                    panelState: panelState,
                    companionManager: companionManager
                )
            )

            let panel = DexterKeyableCommandPanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.contentView = hostingView
            commandPanel = panel
        }

        panelState.query = ""
        panelState.selectedFlatIndex = 0
        panelState.refreshSections(companionManager: companionManager)

        guard let panel = commandPanel else { return }

        NSApp.activate(ignoringOtherApps: true)
        positionPanel(panel)
        panel.alphaValue = 0.92
        panel.makeKeyAndOrderFront(nil)

        installKeyboardMonitor()

        withAnimation(.easeOut(duration: 0.12)) {
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        removeKeyboardMonitor()
        guard let panel = commandPanel else { return }
        panel.orderOut(nil)
    }

    private func positionPanel(_ panel: NSPanel) {
        if let screen = NSApp.keyWindow?.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let originX = screenFrame.midX - panelSize.width / 2
            let originY = screenFrame.midY - panelSize.height / 2 + 40
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        } else {
            panel.center()
        }
    }

    private func installKeyboardMonitor() {
        removeKeyboardMonitor()
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }

            switch event.keyCode {
            case 126: // up
                panelState.moveSelectionUp()
                return nil
            case 125: // down
                panelState.moveSelectionDown()
                return nil
            case 36: // return
                if let result = panelState.flatResults[safeCommandIndex: panelState.selectedFlatIndex] {
                    executeResult(result, useSecondary: false)
                }
                return nil
            case 53: // escape
                dismiss()
                return nil
            default:
                if DexterUniversalCommandShortcutMonitor.isUniversalCommandShortcutForPanel(event) {
                    dismiss()
                    return nil
                }
                return event
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    private func executeResult(_ result: DexterCommandResult, useSecondary: Bool) {
        guard let companionManager, let settingsRouter else { return }
        let action = useSecondary ? (result.secondaryAction ?? result.primaryAction) : result.primaryAction
        dismiss()
        DexterCommandNavigation.perform(
            action: action,
            companionManager: companionManager,
            settingsRouter: settingsRouter
        )
    }
}

extension DexterUniversalCommandShortcutMonitor {
    fileprivate static func isUniversalCommandShortcutForPanel(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
            && event.keyCode == 40
    }
}

private extension Array {
    subscript(safeCommandIndex index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
