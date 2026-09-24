//
//  DexterModelCapability.swift
//  leanring-buddy
//

import Foundation

/// Capabilities the gateway can request from a backend (not every backend supports every capability).
enum DexterModelCapability: String, Equatable, CaseIterable {
    case text = "TEXT"
    case vision = "VISION"
    case reasoning = "REASONING"
    case fast = "FAST"
    case local = "LOCAL"
}

struct DexterModelCapabilitySet: Equatable {
    let capabilities: Set<DexterModelCapability>

    init(_ capabilities: DexterModelCapability...) {
        self.capabilities = Set(capabilities)
    }

    init(capabilities: Set<DexterModelCapability>) {
        self.capabilities = capabilities
    }

    func contains(_ capability: DexterModelCapability) -> Bool {
        capabilities.contains(capability)
    }
}
