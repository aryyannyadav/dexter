//
//  DexterPersonaStarterSuggestionCatalog.swift
//  leanring-buddy
//
//  Generic persona starters — not fabricated user activity. Fills the pool when context is thin.
//

import Foundation

enum DexterPersonaStarterSuggestionCatalog {
    static let maxStartersPerProfile = 9

    struct StarterTemplate: Equatable {
        let slug: String
        let headline: String
        let body: String
        let primaryActionTitle: String
        let category: DexterProfileWorkSuggestionCategory
        let action: DexterProfileWorkSuggestionAction
        let diversityKey: String
    }

    static func starterTemplates(for profileId: UUID) -> [StarterTemplate] {
        switch profileId {
        case DexterSeedProfileIdentifier.studyBuddy:
            return studyBuddyStarters
        case DexterSeedProfileIdentifier.builder:
            return builderStarters
        case DexterSeedProfileIdentifier.researcher:
            return researcherStarters
        case DexterSeedProfileIdentifier.personal:
            return personalStarters
        default:
            return personalStarters
        }
    }

    static func buildStarterSuggestions(
        for profile: DexterProfile,
        evaluatedAt: Date,
        persistence: DexterSuggestionPersistenceStore,
        existingHeadlines: Set<String>,
        maxCount: Int
    ) -> [DexterProfileWorkSuggestion] {
        guard profile.permissions.allowsProactiveSuggestions else { return [] }

        var built: [DexterProfileWorkSuggestion] = []
        var normalizedExisting = Set(existingHeadlines.map(normalizeHeadline))

        for template in starterTemplates(for: profile.id) {
            guard built.count < maxCount else { break }
            let normalizedHeadline = normalizeHeadline(template.headline)
            guard !normalizedExisting.contains(normalizedHeadline) else { continue }

            let suggestion = DexterProfileWorkSuggestion(
                id: "persona_starter:\(template.slug)",
                dexterProfileId: profile.id,
                category: template.category,
                sectionTitle: "SUGGESTION",
                headline: template.headline,
                body: template.body,
                primaryActionTitle: template.primaryActionTitle,
                source: DexterProfileWorkSuggestionSource(
                    kind: .personaStarter,
                    referenceIdentifier: template.slug,
                    displayDetail: profile.name
                ),
                action: template.action,
                priority: 35,
                refreshedAt: evaluatedAt,
                isUnread: true
            )

            guard persistence.shouldOfferSuggestion(
                identifier: suggestion.persistenceIdentifier,
                now: evaluatedAt
            ) else { continue }

            built.append(suggestion)
            normalizedExisting.insert(normalizedHeadline)
        }

        return built
    }

    private static func normalizeHeadline(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let studyBuddyStarters: [StarterTemplate] = [
        StarterTemplate(
            slug: "explain-cpp-topic",
            headline: "Explain this C++ topic",
            body: "Walk me through the concept I'm looking at in plain language.",
            primaryActionTitle: "Yes",
            category: .explain,
            action: .explain(subject: "the C++ topic on my screen"),
            diversityKey: "explain"
        ),
        StarterTemplate(
            slug: "quiz-reading",
            headline: "Quiz me on what I'm reading",
            body: "Turn what I'm studying into a short quiz.",
            primaryActionTitle: "Yes",
            category: .research,
            action: .runAgent(userMessage: "Quiz me on what I'm reading. Ask one question at a time."),
            diversityKey: "quiz"
        ),
        StarterTemplate(
            slug: "exam-prep",
            headline: "Help me prepare for my exam",
            body: "Build a focused study plan from what I'm working on.",
            primaryActionTitle: "Yes",
            category: .task,
            action: .runAgent(userMessage: "Help me prepare for my exam with a short, realistic study plan."),
            diversityKey: "exam"
        ),
        StarterTemplate(
            slug: "revision-notes",
            headline: "Make revision notes",
            body: "Summarize key points I can review later.",
            primaryActionTitle: "Yes",
            category: .research,
            action: .runAgent(userMessage: "Make concise revision notes from what I'm studying."),
            diversityKey: "notes"
        ),
        StarterTemplate(
            slug: "practice-problem",
            headline: "Give me a quick practice problem",
            body: "One problem matched to my level.",
            primaryActionTitle: "Yes",
            category: .task,
            action: .runAgent(userMessage: "Give me one practice problem based on what I'm studying."),
            diversityKey: "practice"
        ),
        StarterTemplate(
            slug: "explain-code",
            headline: "Explain this code",
            body: "Break down what this code is doing.",
            primaryActionTitle: "Yes",
            category: .explain,
            action: .explain(subject: "the code on my screen"),
            diversityKey: "code"
        ),
        StarterTemplate(
            slug: "test-chapter",
            headline: "Test me on this chapter",
            body: "Check my understanding with a few questions.",
            primaryActionTitle: "Yes",
            category: .research,
            action: .runAgent(userMessage: "Test me on this chapter with short questions."),
            diversityKey: "test"
        ),
        StarterTemplate(
            slug: "summarize-studying",
            headline: "Summarize what I'm studying",
            body: "A tight summary I can skim before class.",
            primaryActionTitle: "Yes",
            category: .research,
            action: .research(query: "Summarize what I'm studying in plain language."),
            diversityKey: "summarize"
        ),
        StarterTemplate(
            slug: "study-plan",
            headline: "Create a study plan",
            body: "Organize the next hour of study.",
            primaryActionTitle: "Yes",
            category: .task,
            action: .runAgent(userMessage: "Create a short study plan for what I'm working on."),
            diversityKey: "plan"
        )
    ]

    private static let builderStarters: [StarterTemplate] = [
        StarterTemplate(slug: "explain-code", headline: "Explain this code", body: "Walk through the logic step by step.", primaryActionTitle: "Yes", category: .explain, action: .explain(subject: "the code on my screen"), diversityKey: "explain"),
        StarterTemplate(slug: "find-problem", headline: "Find the problem in this file", body: "Look for likely bugs or smells.", primaryActionTitle: "Yes", category: .explain, action: .runAgent(userMessage: "Help me find the problem in this file."), diversityKey: "debug"),
        StarterTemplate(slug: "help-debug", headline: "Help me debug this", body: "Narrow down what's failing.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me debug what I'm working on."), diversityKey: "debug2"),
        StarterTemplate(slug: "review-function", headline: "Review this function", body: "Suggest improvements and risks.", primaryActionTitle: "Yes", category: .explain, action: .runAgent(userMessage: "Review this function and suggest improvements."), diversityKey: "review"),
        StarterTemplate(slug: "explain-api", headline: "Explain this API", body: "How to use it correctly.", primaryActionTitle: "Yes", category: .explain, action: .explain(subject: "this API"), diversityKey: "api"),
        StarterTemplate(slug: "build-feature", headline: "Help me build this feature", body: "Break it into implementation steps.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me plan and build this feature."), diversityKey: "build"),
        StarterTemplate(slug: "open-project", headline: "Open the relevant project", body: "Get my dev environment ready.", primaryActionTitle: "Yes", category: .integration, action: .runAgent(userMessage: "Help me open or focus the relevant project for this work."), diversityKey: "open"),
        StarterTemplate(slug: "plan-implementation", headline: "Plan the implementation", body: "A clear sequence of steps.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Plan the implementation for what I'm building."), diversityKey: "plan"),
        StarterTemplate(slug: "test-code", headline: "Test this code", body: "What to verify before shipping.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Suggest how to test this code."), diversityKey: "test")
    ]

    private static let researcherStarters: [StarterTemplate] = [
        StarterTemplate(slug: "summarize-topic", headline: "Summarize this topic", body: "Key ideas without fluff.", primaryActionTitle: "Yes", category: .research, action: .research(query: "Summarize this topic in plain language."), diversityKey: "summarize"),
        StarterTemplate(slug: "compare-ideas", headline: "Compare these ideas", body: "Pros, cons, and tradeoffs.", primaryActionTitle: "Yes", category: .research, action: .runAgent(userMessage: "Compare the main ideas I'm researching."), diversityKey: "compare"),
        StarterTemplate(slug: "key-points", headline: "Find the key points", body: "What matters most here.", primaryActionTitle: "Yes", category: .research, action: .research(query: "Find the key points in what I'm reading."), diversityKey: "keys"),
        StarterTemplate(slug: "explain-concept", headline: "Explain this concept", body: "Simple explanation first.", primaryActionTitle: "Yes", category: .explain, action: .explain(subject: "this concept"), diversityKey: "explain"),
        StarterTemplate(slug: "organize-research", headline: "Organize my research", body: "Structure notes and sources.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me organize my research notes."), diversityKey: "organize"),
        StarterTemplate(slug: "research-notes", headline: "Create research notes", body: "Capture what I've learned.", primaryActionTitle: "Yes", category: .research, action: .runAgent(userMessage: "Create research notes from what I'm looking at."), diversityKey: "notes"),
        StarterTemplate(slug: "gaps", headline: "Find gaps in my understanding", body: "Questions I should answer.", primaryActionTitle: "Yes", category: .research, action: .runAgent(userMessage: "Find gaps in my understanding of this topic."), diversityKey: "gaps"),
        StarterTemplate(slug: "questions", headline: "Turn this into questions", body: "Questions to guide reading.", primaryActionTitle: "Yes", category: .research, action: .runAgent(userMessage: "Turn this material into study questions."), diversityKey: "questions"),
        StarterTemplate(slug: "outline", headline: "Build a research outline", body: "Sections for a draft or report.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Build a research outline for this topic."), diversityKey: "outline")
    ]

    private static let personalStarters: [StarterTemplate] = [
        StarterTemplate(slug: "plan-day", headline: "Plan my day", body: "A realistic schedule from my priorities.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me plan my day."), diversityKey: "day"),
        StarterTemplate(slug: "organize-tasks", headline: "Organize my tasks", body: "Sort what needs attention.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me organize my tasks."), diversityKey: "tasks"),
        StarterTemplate(slug: "routine", headline: "Create a routine", body: "A repeatable habit I can follow.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me create a simple routine."), diversityKey: "routine"),
        StarterTemplate(slug: "prioritize", headline: "Help me prioritize", body: "What to do first.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me prioritize what I should do next."), diversityKey: "priority"),
        StarterTemplate(slug: "review-todo", headline: "Review what I need to do", body: "A quick inventory.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Review what I need to do today."), diversityKey: "review"),
        StarterTemplate(slug: "plan-project", headline: "Plan this project", body: "Milestones and next steps.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Help me plan this project."), diversityKey: "project"),
        StarterTemplate(slug: "checklist", headline: "Make a checklist", body: "Concrete items to check off.", primaryActionTitle: "Yes", category: .task, action: .runAgent(userMessage: "Make a checklist for what I'm working on."), diversityKey: "checklist"),
        StarterTemplate(slug: "focus", headline: "Help me focus", body: "One next action to start.", primaryActionTitle: "Yes", category: .continueWork, action: .runAgent(userMessage: "Help me focus on the single most important next step."), diversityKey: "focus"),
        StarterTemplate(slug: "catch-up", headline: "Catch me up", body: "Where I left off.", primaryActionTitle: "Yes", category: .pickUpWhereYouLeftOff, action: .runAgent(userMessage: "Catch me up on what I was working on."), diversityKey: "catchup")
    ]
}
