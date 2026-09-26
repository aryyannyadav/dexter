//
//  DexterHomeSuggestionDisplayPlannerTests.swift
//  leanring-buddyTests
//

import XCTest
@testable import leanring_buddy

final class DexterHomeSuggestionDisplayPlannerTests: XCTestCase {
    func testStableOrderForSameSeed() {
        let items = sampleItems(count: 5)
        let seed = "test-seed"
        let first = DexterHomeSuggestionDisplayPlanner.plan(rankedEligible: items, rotationSeed: seed)
        let second = DexterHomeSuggestionDisplayPlanner.plan(rankedEligible: items, rotationSeed: seed)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testDiversityPrefersDistinctBuckets() {
        let items = [
            makeContext(id: "a", kind: .continueWhereLeftOff, priority: 100),
            makeContext(id: "b", kind: .continueWhereLeftOff, priority: 90),
            makeContext(id: "c", kind: .explainError, priority: 80),
            makeContext(id: "d", kind: .organizeFiles, priority: 70)
        ]
        let planned = DexterHomeSuggestionDisplayPlanner.plan(rankedEligible: items, rotationSeed: "seed")
        XCTAssertEqual(planned.count, 3)
        XCTAssertEqual(Set(planned.map(\.id)), Set(["a", "c", "d"]))
    }

    func testCapsAtSeven() {
        let items = sampleItems(count: 12)
        let planned = DexterHomeSuggestionDisplayPlanner.plan(rankedEligible: items, rotationSeed: "seed")
        XCTAssertLessThanOrEqual(planned.count, 7)
    }

    private func sampleItems(count: Int) -> [DexterHomeSuggestionItem] {
        let kinds: [DexterSuggestionKind] = [
            .continueWhereLeftOff, .explainError, .summarizePage, .organizeFiles, .finishTask
        ]
        return (0..<count).map { index in
            let kind = kinds[index % kinds.count]
            return makeContext(id: "item-\(index)", kind: kind, priority: 100 - index)
        }
    }

    private func makeContext(id: String, kind: DexterSuggestionKind, priority: Int) -> DexterHomeSuggestionItem {
        .context(
            DexterSuggestion(
                id: id,
                kind: kind,
                title: "Title \(id)",
                explanation: "Detail",
                noticedDetail: "Detail",
                primaryActionTitle: "Yes",
                secondaryActionTitle: "No",
                userPromptOnAccept: "Do it",
                outcome: .conversation,
                lifecycle: .new,
                isUnread: true,
                groundedAt: Date(),
                dexterProfileId: nil,
                source: .screenContext,
                priority: priority,
                accentIndex: 0,
                expiresAt: nil,
                contextFingerprint: nil,
                adjustOptions: nil
            )
        )
    }
}
