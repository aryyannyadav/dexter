//
//  DexterSearchService.swift
//  leanring-buddy
//

import Foundation

/// Local, deterministic search across existing Dexter stores (no LLM, no filesystem scan).
enum DexterSearchService {
    private static let maxResultsPerGroup = 6
    private static let maxTotalResults = 40

    static func search(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext,
        activeSuggestions: [DexterSuggestion]
    ) -> [DexterCommandResultSection] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return emptyStateSections(companionManager: companionManager, searchContext: searchContext)
        }

        if let commandSections = DexterUniversalCommandRouter.commandSections(
            forQuery: trimmedQuery,
            companionManager: companionManager
        ) {
            return commandSections
        }

        let normalizedQuery = trimmedQuery.lowercased()
        var allResults: [DexterCommandResult] = []

        allResults.append(contentsOf: profileResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: conversationResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: workspaceResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: fileResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: routineResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: memoryResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: activityResults(query: normalizedQuery, companionManager: companionManager, searchContext: searchContext))
        allResults.append(contentsOf: settingsResults(query: normalizedQuery))
        allResults.append(contentsOf: capabilityResults(query: normalizedQuery, companionManager: companionManager))
        allResults.append(contentsOf: suggestionResults(query: normalizedQuery, suggestions: activeSuggestions, searchContext: searchContext))

        allResults.sort { $0.rankScore > $1.rankScore }
        allResults = Array(allResults.prefix(maxTotalResults))

        if allResults.isEmpty {
            return askDexterFallbackSections(query: trimmedQuery)
        }

        var sections: [DexterCommandResultSection] = []
        if let top = allResults.first {
            sections.append(DexterCommandResultSection(group: .topResult, results: [top]))
        }

        let remaining = allResults.dropFirst()
        let grouped = Dictionary(grouping: remaining) { result -> DexterCommandResultGroup in
            switch result.kind {
            case .conversation: return .conversations
            case .dexter: return .dexters
            case .workspace: return .workspaces
            case .file: return .files
            case .routine: return .routines
            case .memory: return .memories
            case .activity: return .activity
            case .setting: return .settings
            case .capability: return .capabilities
            case .action: return .actions
            case .suggestion: return .suggestions
            case .askDexter: return .askDexter
            }
        }

        for group in DexterCommandResultGroup.allCases where group != .topResult && group != .askDexter {
            guard let results = grouped[group], !results.isEmpty else { continue }
            sections.append(
                DexterCommandResultSection(
                    group: group,
                    results: Array(results.prefix(maxResultsPerGroup))
                )
            )
        }

        if sections.count == 1, sections.first?.group == .topResult,
           DexterUniversalCommandRouter.looksLikeNaturalQuestion(trimmedQuery) {
            sections.append(askDexterFallbackSections(query: trimmedQuery).first!)
        }

        return sections
    }

    private static func emptyStateSections(
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResultSection] {
        var actions: [DexterCommandResult] = [
            makeActionResult(
                id: "action:new-chat",
                title: "New chat",
                subtitle: "Start a fresh conversation",
                systemImage: "square.and.pencil",
                rankScore: 100,
                action: .newChat
            ),
            makeActionResult(
                id: "action:search-conversations",
                title: "Search conversations",
                subtitle: "Type to find a past chat",
                systemImage: "bubble.left.and.bubble.right",
                rankScore: 90,
                action: .openHome
            ),
            makeActionResult(
                id: "action:my-dexters",
                title: "My Dexters",
                subtitle: "Profiles and workspaces",
                systemImage: "person.3",
                rankScore: 85,
                action: .openSettings(page: .myDexters)
            ),
            makeActionResult(
                id: "action:workspaces",
                title: "Workspaces",
                subtitle: "Connected folders and files",
                systemImage: "folder",
                rankScore: 80,
                action: .openSettings(page: .myDexters)
            ),
            makeActionResult(
                id: "action:routines",
                title: "Routines",
                subtitle: "Scheduled Dexter automations",
                systemImage: "clock.arrow.circlepath",
                rankScore: 75,
                action: .showRoutinesList
            ),
            makeActionResult(
                id: "action:settings",
                title: "Settings",
                subtitle: "Preferences and permissions",
                systemImage: "gearshape",
                rankScore: 70,
                action: .openSettings(page: .general)
            )
        ]

        if let profileId = searchContext.activeProfileId,
           let profile = companionManager.dexterProfileStore.profile(withId: profileId) {
            actions.insert(
                makeActionResult(
                    id: "action:continue-active-dexter",
                    title: "Continue \(profile.name)",
                    subtitle: profile.purpose,
                    systemImage: "sparkles",
                    rankScore: 110,
                    action: .openDexterProfile(profileId: profileId),
                    dexterProfileId: profileId
                ),
                at: 0
            )
        }

        return [DexterCommandResultSection(group: .actions, results: actions)]
    }

    private static func askDexterFallbackSections(query: String) -> [DexterCommandResultSection] {
        let result = DexterCommandResult(
            id: "ask-dexter:\(query.hashValue)",
            title: "Ask Dexter",
            subtitle: query,
            kind: .askDexter,
            group: .askDexter,
            systemImageName: "sparkles",
            dexterProfileId: nil,
            rankScore: 10,
            primaryAction: .askDexter(query: query),
            secondaryAction: nil,
            secondaryActionTitle: nil,
            isUnavailable: false,
            unavailableReason: nil
        )
        return [DexterCommandResultSection(group: .askDexter, results: [result])]
    }

    private static func profileResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        companionManager.dexterProfileStore.profiles.compactMap { profile in
            let haystack = (profile.name + " " + profile.purpose + " " + profile.description).lowercased()
            let score = matchScore(query: query, haystack: haystack, recencyBoost: profile.id == searchContext.activeProfileId ? 30 : 0)
            guard score > 0 else { return nil }
            return DexterCommandResult(
                id: "dexter:\(profile.id.uuidString)",
                title: profile.name,
                subtitle: profile.purpose,
                kind: .dexter,
                group: .dexters,
                systemImageName: nil,
                dexterProfileId: profile.id,
                rankScore: score + 20,
                primaryAction: .openDexterProfile(profileId: profile.id),
                secondaryAction: nil,
                secondaryActionTitle: nil,
                isUnavailable: false,
                unavailableReason: nil
            )
        }
    }

    private static func conversationResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        companionManager.dexterRecentConversations.compactMap { conversation in
            var score = matchScore(
                query: query,
                haystack: conversation.title.lowercased(),
                recencyBoost: conversation.id == searchContext.activeConversationId ? 25 : 0
            )

            let preview = conversationMessagePreview(
                conversationId: conversation.id,
                query: query,
                companionManager: companionManager
            )
            if let preview {
                score += matchScore(query: query, haystack: preview.lowercased(), recencyBoost: 0)
            }

            guard score > 0 else { return nil }

            let profileName = companionManager.dexterProfileStore.profile(withId: conversation.dexterProfileId)?.name
            let subtitle = preview ?? profileName

            return DexterCommandResult(
                id: "conversation:\(conversation.id.uuidString)",
                title: conversation.title,
                subtitle: subtitle,
                kind: .conversation,
                group: .conversations,
                systemImageName: "bubble.left.and.bubble.right",
                dexterProfileId: conversation.dexterProfileId,
                rankScore: score + recencyConversationBoost(lastUpdated: conversation.lastUpdated),
                primaryAction: .openConversation(conversationId: conversation.id),
                secondaryAction: nil,
                secondaryActionTitle: nil,
                isUnavailable: false,
                unavailableReason: nil
            )
        }
    }

    private static func conversationMessagePreview(
        conversationId: UUID,
        query: String,
        companionManager: CompanionManager
    ) -> String? {
        let messages = companionManager.searchableConversationMessages(forConversationId: conversationId)
        for message in messages.reversed() {
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if text.lowercased().contains(query) {
                return String(text.prefix(120))
            }
        }
        return nil
    }

    private static func workspaceResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        companionManager.dexterFileWorkspaceStore.workspaces.compactMap { workspace in
            let locationPaths = workspace.locations.compactMap(\.lastResolvedPath).joined(separator: " ")
            let haystack = (workspace.name + " " + locationPaths).lowercased()
            let activeBoost = workspace.dexterProfileId == searchContext.activeProfileId ? 35 : 0
            let score = matchScore(query: query, haystack: haystack, recencyBoost: activeBoost)
            guard score > 0 else { return nil }

            let hasUnavailableLocation = workspace.locations.contains {
                $0.accessState == .permissionRequired || $0.accessState == .missing || $0.accessState == .unavailable
            }

            var subtitle = "Workspace"
            if let fileCount = workspace.indexedFileCount, workspace.indexStatus == .ready {
                subtitle = "\(fileCount) indexed files"
            }
            if hasUnavailableLocation {
                subtitle = "Workspace unavailable — permission required"
            }

            return DexterCommandResult(
                id: "workspace:\(workspace.id.uuidString)",
                title: workspace.name,
                subtitle: subtitle,
                kind: .workspace,
                group: .workspaces,
                systemImageName: "folder",
                dexterProfileId: workspace.dexterProfileId,
                rankScore: score + 15,
                primaryAction: .openWorkspace(profileId: workspace.dexterProfileId),
                secondaryAction: hasUnavailableLocation ? .fixWorkspaceAccess(profileId: workspace.dexterProfileId) : nil,
                secondaryActionTitle: hasUnavailableLocation ? "Fix access" : nil,
                isUnavailable: hasUnavailableLocation,
                unavailableReason: hasUnavailableLocation ? "Workspace unavailable." : nil
            )
        }
    }

    private static func fileResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        var results: [DexterCommandResult] = []
        for workspace in companionManager.dexterFileWorkspaceStore.workspaces {
            guard let snapshot = companionManager.dexterFileWorkspaceStore.indexSnapshot(forWorkspaceId: workspace.id) else {
                continue
            }
            let workspaceBoost = workspace.dexterProfileId == searchContext.activeProfileId ? 40 : 0
            let matches = DexterFileWorkspaceSearch.search(
                snapshot: snapshot,
                query: DexterFileWorkspaceSearch.Query(text: query, maxResults: maxResultsPerGroup)
            )
            for file in matches {
                let score = matchScore(query: query, haystack: (file.name + " " + file.displayPath).lowercased(), recencyBoost: workspaceBoost)
                results.append(
                    DexterCommandResult(
                        id: "file:\(file.fileID)",
                        title: file.name,
                        subtitle: "\(workspace.name) · \(file.displayPath)",
                        kind: .file,
                        group: .files,
                        systemImageName: "doc.text",
                        dexterProfileId: workspace.dexterProfileId,
                        rankScore: score + 10,
                        primaryAction: .openFile(profileId: workspace.dexterProfileId, fileContext: file),
                        secondaryAction: nil,
                        secondaryActionTitle: nil,
                        isUnavailable: false,
                        unavailableReason: nil
                    )
                )
            }
        }
        return results
    }

    private static func routineResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        companionManager.dexterRoutineStore.routines.compactMap { routine in
            let haystack = (
                routine.name + " " + routine.instruction + " " + routine.description
            ).lowercased()
            let profileBoost = routine.dexterProfileId == searchContext.activeProfileId ? 20 : 0
            let score = matchScore(query: query, haystack: haystack, recencyBoost: profileBoost)
            guard score > 0 else { return nil }

            let scheduleSubtitle = routine.trigger.summaryLabel
            let canRunNow = routine.isEnabled && routine.trigger.kind != .taskCompletion

            return DexterCommandResult(
                id: "routine:\(routine.id.uuidString)",
                title: routine.name,
                subtitle: scheduleSubtitle,
                kind: .routine,
                group: .routines,
                systemImageName: "clock.arrow.circlepath",
                dexterProfileId: routine.dexterProfileId,
                rankScore: score + 12,
                primaryAction: .openRoutine(routineId: routine.id),
                secondaryAction: canRunNow ? .runRoutine(routineId: routine.id) : nil,
                secondaryActionTitle: canRunNow ? "Run now" : nil,
                isUnavailable: false,
                unavailableReason: nil
            )
        }
    }

    private static func memoryResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        let profileIds = Set(
            companionManager.dexterProfileStore.profiles.map(\.id)
        )
        var results: [DexterCommandResult] = []

        for profileId in profileIds {
            let memories = companionManager.structuredMemories(forProfileId: profileId)
            let profileName = companionManager.dexterProfileStore.profile(withId: profileId)?.name ?? "Dexter"
            for memory in memories {
                let haystack = (
                    memory.content + " " + (memory.title ?? "") + " " + profileName
                ).lowercased()
                let profileBoost = profileId == searchContext.activeProfileId ? 25 : 0
                let score = matchScore(query: query, haystack: haystack, recencyBoost: profileBoost)
                guard score > 0 else { continue }

                let subtitle = memory.scope == .global
                    ? "Memory · All Dexters"
                    : "Memory · \(profileName)"

                results.append(
                    DexterCommandResult(
                        id: "memory:\(memory.id.uuidString)",
                        title: memory.userFacingSummary,
                        subtitle: subtitle,
                        kind: .memory,
                        group: .memories,
                        systemImageName: "brain.head.profile",
                        dexterProfileId: memory.dexterProfileId ?? profileId,
                        rankScore: score + 14,
                        primaryAction: memory.dexterProfileId != nil
                            ? .openDexterProfile(profileId: memory.dexterProfileId!)
                            : .openSettings(page: .memory),
                        secondaryAction: nil,
                        secondaryActionTitle: nil,
                        isUnavailable: false,
                        unavailableReason: nil
                    )
                )
            }
        }

        return results
    }

    private static func activityResults(
        query: String,
        companionManager: CompanionManager,
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        companionManager.dexterActivityRecorder.recentEvents(
            forProfileId: searchContext.activeProfileId,
            includeGlobal: true,
            limit: 80
        ).compactMap { record in
            let haystack = (
                record.title + " " + (record.summary ?? "") + " " + (record.detail?.actionLabel ?? "")
            ).lowercased()
            let profileBoost = record.dexterProfileId == searchContext.activeProfileId ? 20 : 0
            let score = matchScore(query: query, haystack: haystack, recencyBoost: profileBoost)
            guard score > 0 else { return nil }

            let profileName = record.dexterProfileId.flatMap {
                companionManager.dexterProfileStore.profile(withId: $0)?.name
            }
            let subtitle = profileName.map { "Activity · \($0)" } ?? "Activity"

            return DexterCommandResult(
                id: "activity:\(record.id.uuidString)",
                title: record.title,
                subtitle: subtitle,
                kind: .activity,
                group: .activity,
                systemImageName: "clock.arrow.circlepath",
                dexterProfileId: record.dexterProfileId,
                rankScore: score + 12,
                primaryAction: .openActivity(eventId: record.id, profileId: record.dexterProfileId),
                secondaryAction: nil,
                secondaryActionTitle: nil,
                isUnavailable: false,
                unavailableReason: nil
            )
        }
    }

    private static func settingsResults(query: String) -> [DexterCommandResult] {
        DexterSettingsSearchIndex.matchingEntries(query: query).map { entry in
            let score = matchScore(query: query, haystack: (entry.title + " " + entry.keywords).lowercased(), recencyBoost: 0)
            return DexterCommandResult(
                id: "setting:\(entry.id)",
                title: entry.title,
                subtitle: entry.page.navigationTitle,
                kind: .setting,
                group: .settings,
                systemImageName: entry.page.sidebarSystemImage,
                dexterProfileId: nil,
                rankScore: score + 8,
                primaryAction: .openSettings(page: entry.page),
                secondaryAction: nil,
                secondaryActionTitle: nil,
                isUnavailable: false,
                unavailableReason: nil
            )
        }
    }

    private static func capabilityResults(
        query: String,
        companionManager: CompanionManager
    ) -> [DexterCommandResult] {
        companionManager.dexterProductCapabilities.compactMap { capability in
            let haystack = (capability.displayName + " " + capability.description + " " + capability.category.displayName).lowercased()
            let score = matchScore(query: query, haystack: haystack, recencyBoost: 0)
            guard score > 0 else { return nil }

            return DexterCommandResult(
                id: "capability:\(capability.capabilityID.rawValue)",
                title: capability.displayName,
                subtitle: capability.availability.statusLabel,
                kind: .capability,
                group: .capabilities,
                systemImageName: capability.systemImageName,
                dexterProfileId: nil,
                rankScore: score + 6,
                primaryAction: .openCapability(capabilityID: capability.capabilityID),
                secondaryAction: nil,
                secondaryActionTitle: nil,
                isUnavailable: capability.availability != .available,
                unavailableReason: capability.availability == .available ? nil : capability.availability.statusLabel
            )
        }
    }

    private static func suggestionResults(
        query: String,
        suggestions: [DexterSuggestion],
        searchContext: DexterUniversalCommandSearchContext
    ) -> [DexterCommandResult] {
        suggestions.compactMap { suggestion in
            let haystack = (suggestion.title + " " + suggestion.explanation).lowercased()
            let score = matchScore(query: query, haystack: haystack, recencyBoost: 0)
            guard score > 0 else { return nil }
            let profileBoost = suggestion.dexterProfileId == searchContext.activeProfileId ? 15 : 0
            return DexterCommandResult(
                id: "suggestion:\(suggestion.id)",
                title: suggestion.title,
                subtitle: suggestion.explanation,
                kind: .suggestion,
                group: .suggestions,
                systemImageName: "lightbulb",
                dexterProfileId: suggestion.dexterProfileId,
                rankScore: score + profileBoost + suggestion.priority / 5,
                primaryAction: .askDexter(query: suggestion.userPromptOnAccept),
                secondaryAction: nil,
                secondaryActionTitle: nil,
                isUnavailable: false,
                unavailableReason: nil
            )
        }
    }

    static func makeActionResult(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        rankScore: Int,
        action: DexterCommandResultAction,
        dexterProfileId: UUID? = nil
    ) -> DexterCommandResult {
        DexterCommandResult(
            id: id,
            title: title,
            subtitle: subtitle,
            kind: .action,
            group: .actions,
            systemImageName: systemImage,
            dexterProfileId: dexterProfileId,
            rankScore: rankScore,
            primaryAction: action,
            secondaryAction: nil,
            secondaryActionTitle: nil,
            isUnavailable: false,
            unavailableReason: nil
        )
    }

    private static func recencyConversationBoost(lastUpdated: Date) -> Int {
        let age = Date().timeIntervalSince(lastUpdated)
        if age < 3600 { return 18 }
        if age < 86_400 { return 12 }
        if age < 604_800 { return 6 }
        return 0
    }

    static func matchScore(query: String, haystack: String, recencyBoost: Int) -> Int {
        if haystack.isEmpty || query.isEmpty { return 0 }
        if haystack == query { return 100 + recencyBoost }
        if haystack.hasPrefix(query) { return 80 + recencyBoost }
        if haystack.contains(query) { return 50 + recencyBoost }

        let tokens = query.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 2 }
        if tokens.isEmpty { return 0 }
        var tokenScore = 0
        for token in tokens where haystack.contains(token) {
            tokenScore += 12
        }
        return tokenScore > 0 ? tokenScore + recencyBoost : 0
    }
}

private extension DexterRoutineTriggerKind {
    var displayName: String {
        switch self {
        case .schedule: return "Schedule"
        case .applicationOpened: return "When app opens"
        case .manualOnly: return "Manual"
        case .taskCompletion: return "Task completion"
        }
    }
}
