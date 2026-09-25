//
//  DexterUniversalCommandRouter.swift
//  leanring-buddy
//

import Foundation

/// Deterministic command intents for ⌘K (no LLM).
enum DexterUniversalCommandRouter {
    static func commandSections(
        forQuery query: String,
        companionManager: CompanionManager
    ) -> [DexterCommandResultSection]? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if let action = matchCommand(normalized) {
            let result = DexterSearchService.makeActionResult(
                id: "command:\(normalized)",
                title: action.title,
                subtitle: action.subtitle,
                systemImage: action.systemImage,
                rankScore: 200,
                action: action.action
            )
            return [DexterCommandResultSection(group: .topResult, results: [result])]
        }

        if normalized.hasPrefix("run ") {
            let routineName = String(normalized.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let routine = companionManager.dexterRoutineStore.routines.first(where: {
                $0.name.lowercased() == routineName || $0.name.lowercased().contains(routineName)
            }), routine.trigger.kind != .taskCompletion, routine.isEnabled {
                let result = DexterCommandResult(
                    id: "command-run:\(routine.id.uuidString)",
                    title: "Run \(routine.name)",
                    subtitle: routine.trigger.summaryLabel,
                    kind: .action,
                    group: .topResult,
                    systemImageName: "play.fill",
                    dexterProfileId: routine.dexterProfileId,
                    rankScore: 220,
                    primaryAction: .runRoutine(routineId: routine.id),
                    secondaryAction: .openRoutine(routineId: routine.id),
                    secondaryActionTitle: "Details",
                    isUnavailable: false,
                    unavailableReason: nil
                )
                return [DexterCommandResultSection(group: .topResult, results: [result])]
            }
        }

        return nil
    }

    static func looksLikeNaturalQuestion(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("?") { return true }
        let lowered = trimmed.lowercased()
        let prefixes = ["what ", "why ", "how ", "can you ", "help me ", "explain "]
        return prefixes.contains { lowered.hasPrefix($0) }
    }

    private static func matchCommand(_ normalized: String) -> (title: String, subtitle: String, systemImage: String, action: DexterCommandResultAction)? {
        switch normalized {
        case "new chat", "start new chat":
            return ("New chat", "Start a fresh conversation", "square.and.pencil", .newChat)
        case "open settings", "settings", "preferences":
            return ("Open Settings", "Dexter preferences", "gearshape", .openSettings(page: .general))
        case "search conversations", "conversations":
            return ("Search conversations", "Find a past chat", "bubble.left.and.bubble.right", .openHome)
        case "my dexters", "dexters", "profiles":
            return ("My Dexters", "Manage profiles", "person.3", .openSettings(page: .myDexters))
        case "workspaces", "workspace":
            return ("Workspaces", "Connected folders", "folder", .openSettings(page: .myDexters))
        case "routines", "routine":
            return ("Routines", "View scheduled routines", "clock.arrow.circlepath", .showRoutinesList)
        case "open home", "home":
            return ("Open Home", "Dexter Home window", "house", .openHome)
        default:
            if normalized.hasPrefix("open settings") {
                return ("Open Settings", normalized, "gearshape", .openSettings(page: .general))
            }
            return nil
        }
    }
}
