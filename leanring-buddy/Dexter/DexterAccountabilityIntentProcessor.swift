//
//  DexterAccountabilityIntentProcessor.swift
//  leanring-buddy
//

import Foundation

enum DexterAccountabilityIntentProcessor {
    static func process(
        fromUserMessage userMessage: String,
        memoryStore: MemoryStore
    ) -> DexterMemoryIntentOutcome {
        if let reminderText = DexterAccountabilityIntentRecognizer.extractReminderRequest(fromUserMessage: userMessage) {
            return createReminder(summary: reminderText, memoryStore: memoryStore)
        }

        if userMessage.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "remind me" {
            return .userFacingResponse("What should I remind you about?")
        }

        if let taskTitle = DexterAccountabilityIntentRecognizer.extractStructuredTaskDeclaration(fromUserMessage: userMessage) {
            return upsertDeclaredTask(title: taskTitle, memoryStore: memoryStore)
        }

        return .noMemoryIntent
    }

    private static func createReminder(summary: String, memoryStore: MemoryStore) -> DexterMemoryIntentOutcome {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty else {
            return .userFacingResponse("What should I remind you about?")
        }

        switch DexterMemoryContentPolicy.evaluateForStorage(trimmedSummary, source: .explicitUserUtterance) {
        case .rejected(let reason):
            return .userFacingResponse(reason)
        case .allowed:
            break
        }

        let memoryIdentifier = DexterAccountabilityReminderBridge.persistCommitmentMemory(
            summary: trimmedSummary,
            remindAt: nil,
            memoryStore: memoryStore
        )

        var task = DexterAccountabilityTask(
            title: trimmedSummary,
            status: .notStarted,
            source: .reminder,
            commitment: DexterAccountabilityCommitment(
                summary: trimmedSummary,
                committedAt: Date(),
                remindAt: nil,
                linkedMemoryIdentifier: memoryIdentifier
            ),
            verification: DexterAccountabilityVerification(strategy: "user_confirmed", expectedOutcome: nil)
        )

        memoryStore.upsertAccountabilityTask(task)
        memoryStore.setActiveAccountabilityTaskIdentifier(task.id)
        memoryStore.setActiveTask(description: trimmedSummary, provenance: .explicitUserRequest)

        return .userFacingResponse("Okay — I'll remember: \(trimmedSummary).")
    }

    private static func upsertDeclaredTask(title: String, memoryStore: MemoryStore) -> DexterMemoryIntentOutcome {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return .noMemoryIntent }

        if let existingActive = memoryStore.activeAccountabilityTask() {
            var updatedTask = existingActive
            updatedTask.title = trimmedTitle
            updatedTask.status = .inProgress
            updatedTask.updatedAt = Date()
            memoryStore.upsertAccountabilityTask(updatedTask)
            memoryStore.setActiveAccountabilityTaskIdentifier(updatedTask.id)
        } else {
            let task = DexterAccountabilityTask(
                title: trimmedTitle,
                status: .inProgress,
                source: .explicitUserUtterance
            )
            memoryStore.upsertAccountabilityTask(task)
            memoryStore.setActiveAccountabilityTaskIdentifier(task.id)
        }

        memoryStore.setActiveTask(description: trimmedTitle, provenance: .explicitUserRequest)
        return .appliedSilently
    }
}
