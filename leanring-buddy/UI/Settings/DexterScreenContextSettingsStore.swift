//
//  DexterScreenContextSettingsStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterScreenContextSettingsStore: ObservableObject {
    static let shared = DexterScreenContextSettingsStore()

    @Published var isScreenContextEnabled: Bool {
        didSet { UserDefaults.standard.set(isScreenContextEnabled, forKey: screenContextKey) }
    }

    @Published var isPointerContextEnabled: Bool {
        didSet { UserDefaults.standard.set(isPointerContextEnabled, forKey: pointerContextKey) }
    }

    @Published var isOCREnabled: Bool {
        didSet { UserDefaults.standard.set(isOCREnabled, forKey: ocrKey) }
    }

    @Published var isVisualReasoningEnabled: Bool {
        didSet { UserDefaults.standard.set(isVisualReasoningEnabled, forKey: visualReasoningKey) }
    }

    private let screenContextKey = "dexter.screenContext.enabled"
    private let pointerContextKey = "dexter.screenContext.pointerEnabled"
    private let ocrKey = "dexter.screenContext.ocrEnabled"
    private let visualReasoningKey = "dexter.screenContext.visualReasoningEnabled"

    private init() {
        isScreenContextEnabled = Self.resolvedScreenContextEnabled
        isPointerContextEnabled = Self.resolvedPointerContextEnabled
        isOCREnabled = Self.resolvedOCREnabled
        isVisualReasoningEnabled = Self.resolvedVisualReasoningEnabled
    }

    nonisolated static var resolvedScreenContextEnabled: Bool {
        UserDefaults.standard.object(forKey: "dexter.screenContext.enabled") as? Bool ?? true
    }

    nonisolated static var resolvedPointerContextEnabled: Bool {
        UserDefaults.standard.object(forKey: "dexter.screenContext.pointerEnabled") as? Bool ?? true
    }

    nonisolated static var resolvedOCREnabled: Bool {
        UserDefaults.standard.object(forKey: "dexter.screenContext.ocrEnabled") as? Bool ?? true
    }

    nonisolated static var resolvedVisualReasoningEnabled: Bool {
        UserDefaults.standard.object(forKey: "dexter.screenContext.visualReasoningEnabled") as? Bool ?? true
    }
}
