# AGENTS.md - leanring-buddy (Dexter app target)

The macOS app product name is **Dexter** (`CFBundleDisplayName`). The Xcode target and module remain `leanring-buddy` / `leanring_buddy` for legacy compatibility.

## Entry

- `leanring_buddyApp.swift` — menu bar app entry; `CompanionAppDelegate` starts `MenuBarPanelManager` and `CompanionManager`.

## Core files

- `CompanionManager.swift` — voice pipeline, permissions, Claude/TTS, overlay, onboarding
- `MenuBarPanelManager.swift` / `CompanionPanelView.swift` — menu bar UI
- `OverlayWindow.swift` — cursor overlay and pointing animations
- `CompanionScreenCaptureUtility.swift` — ScreenCaptureKit captures
- `BuddyDictationManager.swift` / `GlobalPushToTalkShortcutMonitor.swift` — push-to-talk

See root `AGENTS.md` for full architecture.
