//
//  DexterConnectorCapability.swift
//  leanring-buddy
//

import Foundation

struct DexterConnectorCapability: Identifiable, Equatable {
    let id: String
    let displayName: String
    let isAvailable: Bool
    let detail: String?

    init(id: String, displayName: String, isAvailable: Bool, detail: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.isAvailable = isAvailable
        self.detail = detail
    }
}
