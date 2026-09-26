//
//  DexterAgentSettingsStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterAgentSettingsStore: ObservableObject {
    static let shared = DexterAgentSettingsStore()

    @Published var speakWhenAgentStartsOrFinishes: Bool {
        didSet { UserDefaults.standard.set(speakWhenAgentStartsOrFinishes, forKey: speakLifecycleKey) }
    }

    @Published var showUpdatesBesideCursor: Bool {
        didSet { UserDefaults.standard.set(showUpdatesBesideCursor, forKey: showBesideCursorKey) }
    }

    @Published var suggestAgentTasks: Bool {
        didSet { UserDefaults.standard.set(suggestAgentTasks, forKey: suggestTasksKey) }
    }

    private let speakLifecycleKey = "dexterAgentsSpeakLifecycle"
    private let showBesideCursorKey = "dexterAgentsShowBesideCursor"
    private let suggestTasksKey = "dexterAgentsSuggestTasks"
    private let suggestTasksLegacyDefaultMigrationKey = "dexterAgentsSuggestTasksLegacyDefaultMigrationV1"

    private init() {
        speakWhenAgentStartsOrFinishes = UserDefaults.standard.bool(forKey: speakLifecycleKey)
        showUpdatesBesideCursor = UserDefaults.standard.bool(forKey: showBesideCursorKey)
        if UserDefaults.standard.object(forKey: suggestTasksKey) == nil {
            suggestAgentTasks = true
            UserDefaults.standard.set(true, forKey: suggestTasksKey)
        } else if !UserDefaults.standard.bool(forKey: suggestTasksLegacyDefaultMigrationKey) {
            // Earlier builds defaulted to `false` when the key was unset; suggestions were effectively off.
            suggestAgentTasks = true
            UserDefaults.standard.set(true, forKey: suggestTasksKey)
            UserDefaults.standard.set(true, forKey: suggestTasksLegacyDefaultMigrationKey)
        } else {
            suggestAgentTasks = UserDefaults.standard.bool(forKey: suggestTasksKey)
        }
    }
}
