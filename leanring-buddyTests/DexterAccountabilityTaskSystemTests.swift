//
//  DexterAccountabilityTaskSystemTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterAccountabilityTaskSystemTests {
    @Test func remindMeCreatesTaskAndCommitmentMemory() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        let outcome = memoryStore.processMemoryIntents(fromUserMessage: "remind me to submit the lab report")

        guard case .userFacingResponse(let response) = outcome else {
            Issue.record("Expected user-facing reminder confirmation.")
            return
        }
        #expect(response.contains("lab report"))

        let tasks = memoryStore.allAccountabilityTasks()
        #expect(tasks.count == 1)
        #expect(tasks.first?.commitment?.linkedMemoryIdentifier != nil)
        #expect(memoryStore.allStructuredMemories().contains { $0.type == .commitment })
    }

    @Test func whatAmIWorkingOnWithoutTasksDoesNotFabricate() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        let response = DexterAccountabilityQueryEngine.respond(
            queryKind: .whatAmIWorkingOn,
            snapshot: memoryStore.accountabilityTaskSnapshot(),
            legacyTaskDescription: nil,
            workflowSummary: nil
        )
        #expect(response.contains("don't have"))
    }

    @Test func whatsNextUsesStoredStep() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        var task = DexterAccountabilityTask(
            title: "Homework",
            status: .inProgress,
            steps: [
                DexterAccountabilityTaskStep(title: "Read chapter"),
                DexterAccountabilityTaskStep(title: "Answer questions")
            ]
        )
        task.steps[0].isCompleted = true
        memoryStore.upsertAccountabilityTask(task)
        memoryStore.setActiveAccountabilityTaskIdentifier(task.id)

        let response = DexterAccountabilityQueryEngine.respond(
            queryKind: .whatsNext,
            snapshot: memoryStore.accountabilityTaskSnapshot(),
            legacyTaskDescription: nil,
            workflowSummary: nil
        )
        #expect(response.contains("Answer questions"))
    }

    @Test func unfinishedListsOpenTasksOnly() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        memoryStore.upsertAccountabilityTask(
            DexterAccountabilityTask(title: "Done task", status: .completed)
        )
        memoryStore.upsertAccountabilityTask(
            DexterAccountabilityTask(title: "Open task", status: .inProgress)
        )

        let response = DexterAccountabilityQueryEngine.respond(
            queryKind: .whatDidILeaveUnfinished,
            snapshot: memoryStore.accountabilityTaskSnapshot(),
            legacyTaskDescription: nil,
            workflowSummary: nil
        )
        #expect(response.contains("Open task"))
        #expect(!response.contains("Done task"))
    }

    @Test func continueMyWorkGroundedInActiveTask() {
        let memoryStore = DefaultMemoryStore.inMemoryForTesting()
        let task = DexterAccountabilityTask(
            title: "Essay draft",
            status: .inProgress,
            steps: [DexterAccountabilityTaskStep(title: "Write outline")]
        )
        memoryStore.upsertAccountabilityTask(task)
        memoryStore.setActiveAccountabilityTaskIdentifier(task.id)

        let response = DexterAccountabilityQueryEngine.respond(
            queryKind: .continueMyWork,
            snapshot: memoryStore.accountabilityTaskSnapshot(),
            legacyTaskDescription: nil,
            workflowSummary: nil
        )
        #expect(response.contains("Essay draft"))
        #expect(response.contains("Write outline"))
    }

    @Test func contextPlannerBuildsIntentStepsFromTask() {
        let snapshot = DexterAccountabilityTaskSnapshot(
            activeTask: DexterAccountabilityTask(
                title: "Ship feature",
                steps: [DexterAccountabilityTaskStep(title: "Run tests")]
            ),
            openTasks: [],
            unfinishedTasks: [],
            pendingReminders: []
        )

        let plan = DexterAccountabilityContextPlanner.intentPlanSupplement(for: snapshot)
        #expect(plan?.steps.first?.title == "Run tests")
    }

    @Test func intentRecognizerDetectsAccountabilityPhrases() {
        #expect(
            DexterAccountabilityIntentRecognizer.recognizeQuery(fromUserMessage: "what's next?")
                == .whatsNext
        )
        #expect(
            DexterAccountabilityIntentRecognizer.recognizeQuery(fromUserMessage: "continue my work")
                == .continueMyWork
        )
    }
}
