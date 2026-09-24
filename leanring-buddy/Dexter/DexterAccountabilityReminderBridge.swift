//
//  DexterAccountabilityReminderBridge.swift
//  leanring-buddy
//
//  Links reminders to structured memory commitments (workflow/automation hooks use the same store).
//

import Foundation

enum DexterAccountabilityReminderBridge {
    /// Persists a commitment memory with optional expiration for scheduling integrations.
    static func persistCommitmentMemory(
        summary: String,
        remindAt: Date?,
        memoryStore: MemoryStore
    ) -> UUID {
        let memoryIdentifier = UUID()
        let expiration = remindAt
        let record = DexterStructuredMemoryRecord(
            id: memoryIdentifier,
            type: .commitment,
            content: summary,
            source: .explicitUserUtterance,
            confidence: 0.95,
            importance: 0.9,
            status: .active,
            expiration: expiration,
            permissions: .defaultForExplicitUser,
            title: "Reminder"
        )
        memoryStore.saveStructuredMemoryRecord(record)
        return memoryIdentifier
    }
}
