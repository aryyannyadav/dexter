//
//  DexterCharacterAssetCatalog.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterCharacterAssetCatalog {
    private static var imageCache: [String: NSImage] = [:]

    static func hasAsset(named assetName: String) -> Bool {
        if imageCache[assetName] != nil { return true }
        return NSImage(named: assetName) != nil
    }

    static func cachedImage(named assetName: String) -> NSImage? {
        if let cached = imageCache[assetName] {
            return cached
        }
        guard let image = NSImage(named: assetName) else {
            print("[DEXTER][CHARACTER] missing asset \(assetName)")
            return nil
        }
        imageCache[assetName] = image
        return image
    }

    static func stateAssetName(for state: DexterCharacterState) -> String {
        switch state {
        case .idle: return "DexterCharacterIdle"
        case .listening: return "DexterCharacterListening"
        case .thinking: return "DexterCharacterThinking"
        case .speaking: return "DexterCharacterSpeaking"
        case .working: return "DexterCharacterWorking"
        case .success: return "DexterCharacterSuccess"
        case .error: return "DexterCharacterError"
        case .sleeping: return "DexterCharacterSleeping"
        }
    }

    /// State sheet artwork when present; otherwise profile-specific legacy base art.
    static func resolvedAssetName(
        definition: DexterCharacterDefinition,
        appearance: DexterCharacterAppearance,
        state: DexterCharacterState
    ) -> String {
        let stateAsset = stateAssetName(for: state)
        if hasAsset(named: stateAsset) {
            return stateAsset
        }
        return definition.baseAssetName
    }

    static func resolvedBaseAssetName(
        definition: DexterCharacterDefinition,
        appearance: DexterCharacterAppearance
    ) -> String {
        resolvedAssetName(definition: definition, appearance: appearance, state: .idle)
    }

    /// Illustrated state sheet — use stage presentation (no circular avatar chrome).
    static func presentationModeForCompactSurfaces(state: DexterCharacterState) -> DexterCharacterPresentationMode {
        if hasAsset(named: stateAssetName(for: state)) {
            return .stage
        }
        return .avatar
    }
}
