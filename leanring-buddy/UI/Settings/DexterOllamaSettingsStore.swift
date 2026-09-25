//
//  DexterOllamaSettingsStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterOllamaSettingsStore: ObservableObject {
    static let shared = DexterOllamaSettingsStore()

    @Published var isOllamaProviderEnabled: Bool {
        didSet { UserDefaults.standard.set(isOllamaProviderEnabled, forKey: enabledKey) }
    }

    @Published var endpointURLString: String {
        didSet {
            let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: endpointKey)
        }
    }

    private let enabledKey = "dexterOllamaProviderEnabled"
    private let endpointKey = "dexterOllamaEndpointURLString"

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            isOllamaProviderEnabled = true
        } else {
            isOllamaProviderEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }

        let storedEndpoint = UserDefaults.standard.string(forKey: endpointKey)
        endpointURLString = storedEndpoint ?? OllamaProvider.defaultEndpointString
    }

    var resolvedEndpointURL: URL? {
        let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "http://\(trimmed)")
    }
}
