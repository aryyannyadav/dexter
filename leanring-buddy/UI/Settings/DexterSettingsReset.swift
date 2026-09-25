//
//  DexterSettingsReset.swift
//  leanring-buddy
//

import Foundation

enum DexterSettingsReset {
    /// Resets Dexter UI preferences only — not conversations, saved memory, or Dexter profiles.
    static func resetDexterUIPreferences() {
        let keys = [
            "dexter.appearance.mode",
            "dexter.appearance.productAccent",
            "dexterCursorStyleOption",
            "dexterCursorAccentColorOption",
            "dexterDockCursorEnabled",
            "dexterCursorSizeOption",
            "dexter.general.openHomeWhenLaunch",
            "dexter.screenContext.enabled",
            "dexter.screenContext.pointerEnabled",
            "dexter.screenContext.ocrEnabled",
            "dexter.screenContext.visualReasoningEnabled",
            "dexterAutonomousComputerControlEnabled",
            "dexter.actionPermission.autoApproveLowRiskActions",
            "dexterAgentsSpeakLifecycle",
            "dexterAgentsShowBesideCursor",
            "dexterAgentsSuggestTasks",
            "dexterOllamaProviderEnabled",
            "dexterOllamaEndpointURLString",
            "dexter.voice.pushToTalkEnabled",
            "dexter.voice.spokenResponsesEnabled",
            "dexter.developerModeEnabled"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        DexterAppearanceSettingsStore.accentHexForRendering = DexterProductAccentOption.dexterCyan.accentHex
    }
}
