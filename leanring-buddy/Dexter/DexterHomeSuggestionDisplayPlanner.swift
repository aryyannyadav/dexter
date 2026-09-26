//
//  DexterHomeSuggestionDisplayPlanner.swift
//  leanring-buddy
//
//  Presentation-only diversity + stable rotation for Home/Notch/Sidebar surfaces.
//

import Foundation

enum DexterHomeSuggestionDiversityBucket: String, Hashable, CaseIterable {
    case continueWork
    case explain
    case application
    case workspace
    case research
    case productivity
    case capability
}

enum DexterHomeSuggestionDisplayPlanner {
    static let homeDisplayLimit = 7

    static func rotationSeed(
        activeProfileId: UUID?,
        evaluatedAt: Date,
        rankedItemIDs: [String]
    ) -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: evaluatedAt) ?? 0
        let profileKey = activeProfileId?.uuidString ?? "global"
        let idFingerprint = rankedItemIDs.sorted().joined(separator: "|")
        return "\(profileKey)-\(dayOfYear)-\(idFingerprint.hashValue)"
    }

    static func plan(
        rankedEligible: [DexterHomeSuggestionItem],
        maxCount: Int = homeDisplayLimit,
        rotationSeed: String
    ) -> [DexterHomeSuggestionItem] {
        let diverse = selectWithCategoryDiversity(from: rankedEligible, maxCount: maxCount)
        return stableDisplayOrder(for: diverse, rotationSeed: rotationSeed)
    }

    /// Home aggregate: spread across Dexters, then category diversity, then stable shuffle.
    static func planAggregatedHome(
        rankedEligible: [DexterHomeSuggestionItem],
        maxCount: Int = homeDisplayLimit,
        rotationSeed: String
    ) -> [DexterHomeSuggestionItem] {
        let personaSpread = selectWithPersonaSpread(from: rankedEligible, maxCount: maxCount)
        var diverse = selectWithCategoryDiversity(from: personaSpread, maxCount: maxCount)
        if diverse.count < maxCount {
            for item in rankedEligible where !diverse.contains(where: { $0.id == item.id }) {
                diverse.append(item)
                if diverse.count >= maxCount { break }
            }
        }
        return stableDisplayOrder(for: Array(diverse.prefix(maxCount)), rotationSeed: rotationSeed)
    }

    static func personaDisplayName(for item: DexterHomeSuggestionItem) -> String? {
        switch item {
        case .profileWork(let work):
            return work.source.displayDetail
        case .context:
            return nil
        }
    }

    static func categoryLabel(for item: DexterHomeSuggestionItem) -> String {
        switch diversityBucket(for: item) {
        case .continueWork: return "Continue"
        case .explain: return "Explain"
        case .application: return "Open"
        case .workspace: return "Workspace"
        case .research: return "Research"
        case .productivity: return "Productivity"
        case .capability: return "Dexter"
        }
    }

    static func diversityBucket(for item: DexterHomeSuggestionItem) -> DexterHomeSuggestionDiversityBucket {
        switch item {
        case .context(let suggestion):
            switch suggestion.kind {
            case .continueWhereLeftOff, .finishTask:
                return .continueWork
            case .explainError:
                return .explain
            case .summarizePage:
                return .research
            case .organizeFiles:
                return .workspace
            }
            switch suggestion.source {
            case .integration, .activeApplication, .browserContext:
                return .application
            case .workflow, .unfinishedTask:
                return .continueWork
            case .screenContext:
                return .explain
            default:
                break
            }
            if suggestion.outcome == .agentTask {
                return .capability
            }
            if suggestion.outcome == .teaching {
                return .explain
            }
            return .productivity
        case .profileWork(let workSuggestion):
            switch workSuggestion.category {
            case .continueWork, .pickUpWhereYouLeftOff:
                return .continueWork
            case .explain:
                return .explain
            case .integration:
                return .application
            case .task:
                return .workspace
            case .research:
                return .research
            }
        }
    }

    private static func selectWithPersonaSpread(
        from ranked: [DexterHomeSuggestionItem],
        maxCount: Int
    ) -> [DexterHomeSuggestionItem] {
        guard !ranked.isEmpty else { return [] }

        var buckets: [UUID: [DexterHomeSuggestionItem]] = [:]
        var globalItems: [DexterHomeSuggestionItem] = []
        for item in ranked {
            if let profileId = item.dexterProfileId {
                buckets[profileId, default: []].append(item)
            } else {
                globalItems.append(item)
            }
        }

        var selected: [DexterHomeSuggestionItem] = []
        var profileOrder = buckets.keys.sorted { $0.uuidString < $1.uuidString }
        var round = 0
        while selected.count < maxCount {
            var addedThisRound = false
            for profileId in profileOrder {
                guard let queue = buckets[profileId], round < queue.count else { continue }
                let candidate = queue[round]
                guard !selected.contains(where: { $0.id == candidate.id }) else { continue }
                selected.append(candidate)
                addedThisRound = true
                if selected.count >= maxCount { return selected }
            }
            if !addedThisRound {
                break
            }
            round += 1
        }

        for item in globalItems where !selected.contains(where: { $0.id == item.id }) {
            selected.append(item)
            if selected.count >= maxCount { break }
        }

        for item in ranked where !selected.contains(where: { $0.id == item.id }) {
            selected.append(item)
            if selected.count >= maxCount { break }
        }

        return selected
    }

    private static func selectWithCategoryDiversity(
        from ranked: [DexterHomeSuggestionItem],
        maxCount: Int
    ) -> [DexterHomeSuggestionItem] {
        guard !ranked.isEmpty else { return [] }

        var selected: [DexterHomeSuggestionItem] = []
        var usedBuckets: Set<DexterHomeSuggestionDiversityBucket> = []

        for item in ranked {
            let bucket = diversityBucket(for: item)
            guard !usedBuckets.contains(bucket) else { continue }
            selected.append(item)
            usedBuckets.insert(bucket)
            if selected.count >= maxCount { return selected }
        }

        for item in ranked where !selected.contains(where: { $0.id == item.id }) {
            selected.append(item)
            if selected.count >= maxCount { break }
        }

        return selected
    }

    private static func stableDisplayOrder(
        for items: [DexterHomeSuggestionItem],
        rotationSeed: String
    ) -> [DexterHomeSuggestionItem] {
        items.sorted { lhs, rhs in
            stableSortKey(rotationSeed: rotationSeed, itemID: lhs.id)
                < stableSortKey(rotationSeed: rotationSeed, itemID: rhs.id)
        }
    }

    private static func stableSortKey(rotationSeed: String, itemID: String) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(rotationSeed)
        hasher.combine(itemID)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }
}
