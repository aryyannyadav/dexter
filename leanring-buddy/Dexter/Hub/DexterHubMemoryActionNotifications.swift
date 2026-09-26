//
//  DexterHubMemoryActionNotifications.swift
//

import Foundation

extension Notification.Name {
    /// User tapped View on Hub for a saved memory — open Dexter memory UI on the Mac.
    static let dexterHubViewMemoryRecordRequested = Notification.Name("dexterHubViewMemoryRecordRequested")
    /// User tapped Forget on Hub for a known memory record id.
    static let dexterHubForgetMemoryRecordRequested = Notification.Name("dexterHubForgetMemoryRecordRequested")
}

enum DexterHubMemoryActionNotifications {
    static let memoryRecordIdentifierUserInfoKey = "memoryRecordIdentifier"
}
