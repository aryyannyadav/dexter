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

    private init() {
        speakWhenAgentStartsOrFinishes = UserDefaults.standard.bool(forKey: speakLifecycleKey)
        showUpdatesBesideCursor = UserDefaults.standard.bool(forKey: showBesideCursorKey)
        suggestAgentTasks = UserDefaults.standard.bool(forKey: suggestTasksKey)
    }
}
