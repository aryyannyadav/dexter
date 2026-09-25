//
//  DexterSuggestionEngine.swift
//  leanring-buddy
//
//  Deterministic, context-grounded suggestions only. No model inference.
//

import Foundation

enum DexterSuggestionEngine {
    private static let contextFreshnessInterval: TimeInterval = 6 * 60 * 60
    private static let contextSuggestionTTL: TimeInterval = 30 * 60

    static func generateSuggestions(
        input: DexterSuggestionEngineInput,
        persistence: DexterSuggestionPersistenceStore
    ) -> [DexterSuggestion] {
        var candidates: [DexterSuggestion] = []

        if let explainError = explainErrorSuggestion(from: input) {
            candidates.append(explainError)
        }
        if let summarizePage = summarizePageSuggestion(from: input) {
            candidates.append(summarizePage)
        }
        if let explainTerminal = explainTerminalSuggestion(from: input) {
            candidates.append(explainTerminal)
        }
        if let finishTask = finishTaskSuggestion(from: input) {
            candidates.append(finishTask)
        }
        if let organizeFiles = organizeFilesSuggestion(from: input) {
            candidates.append(organizeFiles)
        }
        if let profileStudy = profileScopedStudySuggestion(from: input) {
            candidates.append(profileStudy)
        }
        if let profileBuilder = profileScopedBuilderSuggestion(from: input) {
            candidates.append(profileBuilder)
        }
        if let continueWork = continueWhereLeftOffSuggestion(from: input) {
            candidates.append(continueWork)
        }
        if let workspaceSuggestion = fileWorkspaceGroundedSuggestion(from: input) {
            candidates.append(workspaceSuggestion)
        }

        return candidates.filter { persistence.shouldOfferSuggestion(identifier: $0.id, now: input.evaluatedAt) }
    }

    private static func isContextFresh(_ snapshot: DexterContextSnapshot?, evaluatedAt: Date) -> Bool {
        guard let snapshot else { return false }
        return evaluatedAt.timeIntervalSince(snapshot.capturedAt) <= contextFreshnessInterval
    }

    private static func contextExpiresAt(evaluatedAt: Date) -> Date {
        evaluatedAt.addingTimeInterval(contextSuggestionTTL)
    }

    private static func explainErrorSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard let snapshot = input.contextSnapshot, isContextFresh(snapshot, evaluatedAt: input.evaluatedAt) else {
            return nil
        }

        let windowTitle = snapshot.activeWindowTitle?.lowercased() ?? ""
        let appName = snapshot.activeApplicationName?.lowercased() ?? ""
        let selectedText = snapshot.selectedText?.lowercased() ?? ""

        let looksLikeBuildFailure =
            windowTitle.contains("build failed")
            || windowTitle.contains("failed")
            || selectedText.contains("error:")
            || selectedText.contains("xcodebuild")

        let isLikelyDevContext = appName.contains("xcode") || appName.contains("terminal") || appName.contains("iterm")

        guard looksLikeBuildFailure && isLikelyDevContext else { return nil }

        let detail = snapshot.activeWindowTitle ?? "An error may be visible in your developer tools."
        let fingerprint = "explain_error:\(detail.prefix(48))"

        return DexterSuggestion(
            id: fingerprint,
            kind: .explainError,
            title: "Explain this error",
            explanation: "I can look at the current screen and explain what's going wrong.",
            noticedDetail: detail,
            primaryActionTitle: "Explain it",
            secondaryActionTitle: "Adjust",
            userPromptOnAccept: "Help me understand and fix this error.",
            outcome: .teaching,
            dexterProfileId: input.activeProfileId,
            source: .screenContext,
            priority: 90,
            accentIndex: 1,
            expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
            contextFingerprint: fingerprint,
            adjustOptions: [
                DexterSuggestionAdjustOption(title: "Simple", userPrompt: "Explain this error in simple terms."),
                DexterSuggestionAdjustOption(title: "Technical", userPrompt: "Explain this error technically with likely fixes.")
            ]
        )
    }

    private static func summarizePageSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard let snapshot = input.contextSnapshot, isContextFresh(snapshot, evaluatedAt: input.evaluatedAt) else {
            return nil
        }

        let pageTitle = snapshot.browserPageTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pageURL = snapshot.browserURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appName = snapshot.activeApplicationName?.lowercased() ?? ""

        let hasBrowserPage = !pageTitle.isEmpty || !pageURL.isEmpty
        let isBrowserApp = appName.contains("safari") || appName.contains("chrome") || appName.contains("firefox") || appName.contains("arc")

        guard hasBrowserPage || (isBrowserApp && !(snapshot.activeWindowTitle ?? "").isEmpty) else {
            return nil
        }

        let detail = pageTitle.isEmpty ? (pageURL.isEmpty ? (snapshot.activeWindowTitle ?? "this page") : pageURL) : pageTitle
        let fingerprint = "summarize_page:\(detail.prefix(48))"

        return DexterSuggestion(
            id: fingerprint,
            kind: .summarizePage,
            title: "Summarize this page",
            explanation: "I can summarize what you're reading using browser context Dexter already collected.",
            noticedDetail: detail,
            primaryActionTitle: "Summarize",
            secondaryActionTitle: "Adjust",
            userPromptOnAccept: "Summarize this page for me in a few bullet points.",
            outcome: .conversation,
            dexterProfileId: input.activeProfileId,
            source: .browserContext,
            priority: 80,
            accentIndex: 0,
            expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
            contextFingerprint: fingerprint,
            adjustOptions: [
                DexterSuggestionAdjustOption(title: "Short", userPrompt: "Give me a very short summary of this page."),
                DexterSuggestionAdjustOption(title: "Detailed", userPrompt: "Summarize this page with key details and takeaways.")
            ]
        )
    }

    private static func explainTerminalSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard let snapshot = input.contextSnapshot, isContextFresh(snapshot, evaluatedAt: input.evaluatedAt) else {
            return nil
        }
        let appName = snapshot.activeApplicationName?.lowercased() ?? ""
        guard appName.contains("terminal") || appName.contains("iterm") else { return nil }

        let selectedText = snapshot.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !selectedText.isEmpty else { return nil }

        let fingerprint = "explain_terminal:\(selectedText.prefix(48))"
        return DexterSuggestion(
            id: fingerprint,
            kind: .explainError,
            title: "Explain this command",
            explanation: "I can explain the terminal output or command you have selected.",
            noticedDetail: selectedText,
            primaryActionTitle: "Explain it",
            userPromptOnAccept: "Explain this terminal output and what I should do next: \(selectedText)",
            outcome: .teaching,
            dexterProfileId: input.activeProfileId,
            source: .activeApplication,
            priority: 85,
            accentIndex: 2,
            expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
            contextFingerprint: fingerprint
        )
    }

    private static func finishTaskSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        let taskLine = input.activeWorkflowTaskTitle
            ?? input.activeTaskDescription
            ?? input.workflowContextSummary

        guard let taskLine, !taskLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let fingerprint = "finish_task:\(taskLine.prefix(48))"

        return DexterSuggestion(
            id: fingerprint,
            kind: .finishTask,
            title: "Help me finish this task",
            explanation: "You have an active task in Dexter. I can help with the next step.",
            noticedDetail: taskLine,
            primaryActionTitle: "Continue",
            userPromptOnAccept: "Help me finish this task: \(taskLine)",
            outcome: .agentTask,
            dexterProfileId: input.activeProfileId,
            source: .unfinishedTask,
            priority: 75,
            accentIndex: 3
        )
    }

    private static func organizeFilesSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard let snapshot = input.contextSnapshot, isContextFresh(snapshot, evaluatedAt: input.evaluatedAt) else {
            return nil
        }

        let appName = snapshot.activeApplicationName?.lowercased() ?? ""
        let windowTitle = snapshot.activeWindowTitle?.lowercased() ?? ""

        guard appName.contains("finder") else { return nil }
        guard windowTitle.contains("download") || windowTitle.contains("desktop") || windowTitle.contains("document") else {
            return nil
        }

        let detail = snapshot.activeWindowTitle ?? "Finder"
        let fingerprint = "organize_files:\(detail.prefix(48))"

        return DexterSuggestion(
            id: fingerprint,
            kind: .organizeFiles,
            title: "Organize these files",
            explanation: "I can suggest a safe organization plan in folders Dexter is allowed to access.",
            noticedDetail: detail,
            primaryActionTitle: "Suggest a plan",
            userPromptOnAccept: "Help me organize the files in this Finder window safely.",
            outcome: .action,
            dexterProfileId: input.activeProfileId,
            source: .activeApplication,
            priority: 60,
            accentIndex: 4,
            expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
            contextFingerprint: fingerprint
        )
    }

    private static func profileScopedStudySuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard input.activeProfileId == DexterSeedProfileIdentifier.studyBuddy else { return nil }
        guard let snapshot = input.contextSnapshot, isContextFresh(snapshot, evaluatedAt: input.evaluatedAt) else {
            return nil
        }
        let selectedText = snapshot.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !selectedText.isEmpty else { return nil }

        let fingerprint = "study_quiz:\(selectedText.prefix(40))"
        return DexterSuggestion(
            id: fingerprint,
            kind: .continueWhereLeftOff,
            title: "Quiz me on this",
            explanation: "Turn what you're looking at into a quick study check.",
            noticedDetail: selectedText,
            primaryActionTitle: "Quiz me",
            userPromptOnAccept: "Quiz me on this material: \(selectedText)",
            outcome: .teaching,
            dexterProfileId: input.activeProfileId,
            source: .currentDexter,
            priority: 82,
            accentIndex: 5,
            expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
            contextFingerprint: fingerprint
        )
    }

    private static func profileScopedBuilderSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard input.activeProfileId == DexterSeedProfileIdentifier.builder else { return nil }
        guard let snapshot = input.contextSnapshot, isContextFresh(snapshot, evaluatedAt: input.evaluatedAt) else {
            return nil
        }
        let appName = snapshot.activeApplicationName?.lowercased() ?? ""
        guard appName.contains("code") || appName.contains("xcode") else { return nil }

        let fingerprint = "builder_review:\(snapshot.activeWindowTitle ?? "code")"
        return DexterSuggestion(
            id: fingerprint,
            kind: .explainError,
            title: "Review this code",
            explanation: "I can review the code context on screen and suggest improvements.",
            noticedDetail: snapshot.activeWindowTitle ?? "Your editor",
            primaryActionTitle: "Review it",
            userPromptOnAccept: "Review the code I'm working on and suggest improvements.",
            outcome: .conversation,
            dexterProfileId: input.activeProfileId,
            source: .currentDexter,
            priority: 78,
            accentIndex: 1,
            expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
            contextFingerprint: fingerprint
        )
    }

    private static func fileWorkspaceGroundedSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard input.fileWorkspaceIndexStatus == .ready,
              let workspaceName = input.fileWorkspaceName,
              !workspaceName.isEmpty else {
            return nil
        }

        if input.activeProfileId == DexterSeedProfileIdentifier.builder {
            let fingerprint = "workspace_builder:\(workspaceName)"
            return DexterSuggestion(
                id: fingerprint,
                kind: .explainError,
                title: "Review the changes in this project",
                explanation: "Your \(workspaceName) workspace is indexed and ready.",
                noticedDetail: workspaceName,
                primaryActionTitle: "Review changes",
                userPromptOnAccept: "Review recent changes in my \(workspaceName) workspace and summarize what I should look at.",
                outcome: .conversation,
                dexterProfileId: input.activeProfileId,
                source: .currentDexter,
                priority: 74,
                accentIndex: 2,
                expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
                contextFingerprint: fingerprint
            )
        }

        if input.activeProfileId == DexterSeedProfileIdentifier.studyBuddy,
           let recentFile = input.fileWorkspaceRecentFileName {
            let fingerprint = "workspace_study:\(recentFile)"
            return DexterSuggestion(
                id: fingerprint,
                kind: .continueWhereLeftOff,
                title: "Continue studying from your latest notes",
                explanation: "Pick up from \(recentFile) in \(workspaceName).",
                noticedDetail: recentFile,
                primaryActionTitle: "Continue",
                userPromptOnAccept: "Help me continue studying from \(recentFile) in my workspace.",
                outcome: .teaching,
                dexterProfileId: input.activeProfileId,
                source: .currentDexter,
                priority: 76,
                accentIndex: 5,
                expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
                contextFingerprint: fingerprint
            )
        }

        if input.activeProfileId == DexterSeedProfileIdentifier.researcher,
           let recentFile = input.fileWorkspaceRecentFileName,
           recentFile.lowercased().hasSuffix(".pdf") {
            let fingerprint = "workspace_research:\(recentFile)"
            return DexterSuggestion(
                id: fingerprint,
                kind: .summarizePage,
                title: "Summarize the new paper you added",
                explanation: "I can work from \(recentFile) in your workspace index (metadata and excerpt only).",
                noticedDetail: recentFile,
                primaryActionTitle: "Summarize",
                userPromptOnAccept: "Summarize \(recentFile) from my research workspace.",
                outcome: .conversation,
                dexterProfileId: input.activeProfileId,
                source: .currentDexter,
                priority: 72,
                accentIndex: 6,
                expiresAt: contextExpiresAt(evaluatedAt: input.evaluatedAt),
                contextFingerprint: fingerprint
            )
        }

        return nil
    }

    private static func continueWhereLeftOffSuggestion(from input: DexterSuggestionEngineInput) -> DexterSuggestion? {
        guard let recentTitle = input.recentConversationTitles.first,
              !recentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let fingerprint = "continue:\(recentTitle.prefix(48))"

        return DexterSuggestion(
            id: fingerprint,
            kind: .continueWhereLeftOff,
            title: "Continue where you left off",
            explanation: "Pick up your recent conversation without starting from scratch.",
            noticedDetail: recentTitle,
            primaryActionTitle: "Continue",
            secondaryActionTitle: "Dismiss",
            userPromptOnAccept: "Let's continue where we left off on: \(recentTitle)",
            outcome: .conversation,
            dexterProfileId: input.activeProfileId,
            source: .recentConversation,
            priority: 55,
            accentIndex: 3
        )
    }
}
