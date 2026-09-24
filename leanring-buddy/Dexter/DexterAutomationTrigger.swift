//
//  DexterAutomationTrigger.swift
//  leanring-buddy
//
//  Internal trigger surface for the unified skill runtime (marketplace later).
//

import Foundation

enum DexterAutomationTriggerKind: String, Codable, Equatable, CaseIterable {
    case manualInvocation = "MANUAL_INVOCATION"
    case scheduled = "SCHEDULED"
    case event = "EVENT"
    case context = "CONTEXT"
}

struct DexterAutomationTrigger: Equatable, Codable {
    let kind: DexterAutomationTriggerKind
    let userMessage: String?
    /// Human-readable schedule spec (cron/interval) — scheduling hooks come later.
    let scheduledDescription: String?
    let proactiveEventKind: DexterProactiveEventKind?
    let proactiveEventIdentifier: UUID?
    let contextConditionDescription: String?

    static func manualInvocation(userMessage: String) -> DexterAutomationTrigger {
        DexterAutomationTrigger(
            kind: .manualInvocation,
            userMessage: userMessage,
            scheduledDescription: nil,
            proactiveEventKind: nil,
            proactiveEventIdentifier: nil,
            contextConditionDescription: nil
        )
    }

    static func scheduled(description: String) -> DexterAutomationTrigger {
        DexterAutomationTrigger(
            kind: .scheduled,
            userMessage: nil,
            scheduledDescription: description,
            proactiveEventKind: nil,
            proactiveEventIdentifier: nil,
            contextConditionDescription: nil
        )
    }

    static func event(_ event: DexterProactiveEvent) -> DexterAutomationTrigger {
        DexterAutomationTrigger(
            kind: .event,
            userMessage: nil,
            scheduledDescription: nil,
            proactiveEventKind: event.kind,
            proactiveEventIdentifier: event.id,
            contextConditionDescription: event.title
        )
    }

    static func context(conditionDescription: String) -> DexterAutomationTrigger {
        DexterAutomationTrigger(
            kind: .context,
            userMessage: nil,
            scheduledDescription: nil,
            proactiveEventKind: nil,
            proactiveEventIdentifier: nil,
            contextConditionDescription: conditionDescription
        )
    }
}
