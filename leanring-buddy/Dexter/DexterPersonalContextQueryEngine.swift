//
//  DexterPersonalContextQueryEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterPersonalContextQueryEngine {
    static func respond(
        queryKind: DexterPersonalContextQueryKind,
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> String {
        switch queryKind {
        case .whereWasI:
            return whereWasI(graph: graph, authorizedInput: authorizedInput)
        case .whatWasIDoing:
            return whatWasIDoing(graph: graph, authorizedInput: authorizedInput)
        case .continueWhereLeftOff:
            return continueWhereLeftOff(graph: graph, authorizedInput: authorizedInput)
        case .catchMeUp:
            return catchMeUp(graph: graph, authorizedInput: authorizedInput)
        case .whatShouldIDoNext:
            return whatShouldIDoNext(graph: graph, authorizedInput: authorizedInput)
        }
    }

    private static func whereWasI(
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> String {
        let crossApplication = DexterCrossApplicationContextComposer.compose(
            graph: graph,
            authorizedInput: authorizedInput
        )

        if !crossApplication.relationshipSummaries.isEmpty {
            let summaryLines = crossApplication.relationshipSummaries.prefix(4).joined(separator: " ")
            return "From authorized screen, project memory, tasks, and recent actions: \(summaryLines)"
        }

        if let application = graph.entities.first(where: { $0.kind == .application }) {
            let detail = application.detail.map { " (\($0))" } ?? ""
            return "From authorized context, you were last in \(application.title)\(detail)."
        }

        if let windowTitle = authorizedInput.activeWindowTitle?.nonEmptyTrimmedValue {
            return "From authorized window context, you were in “\(windowTitle)”."
        }

        if let lastConversation = authorizedInput.recentConversationExchanges.last {
            return "I don't have a fresh app snapshot, but your last message was: “\(lastConversation.userTranscript)”."
        }

        return "I don't have enough authorized context to say where you were. Open the app you care about or ask again after Dexter collects environment context."
    }

    private static func whatWasIDoing(
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> String {
        if let task = graph.entities.first(where: { $0.id == "task:current" || $0.kind == .task }),
           let detail = task.detail?.nonEmptyTrimmedValue {
            return "Your current task is: \(detail)."
        }

        if let workflow = graph.entities.first(where: { $0.kind == .workflow }),
           let detail = workflow.detail?.nonEmptyTrimmedValue {
            return "You were in workflow “\(detail)”."
        }

        if let lastAction = authorizedInput.recentActionSummaries.last {
            return "Your most recent Dexter action was: \(lastAction)."
        }

        return "I don't have a confident picture of what you were doing from authorized context alone."
    }

    private static func continueWhereLeftOff(
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> String {
        var parts: [String] = []

        if let task = graph.entities.first(where: { $0.kind == .task })?.detail?.nonEmptyTrimmedValue {
            parts.append("Continue task: \(task).")
        }

        if let workflow = graph.entities.first(where: { $0.kind == .workflow })?.detail?.nonEmptyTrimmedValue {
            parts.append("Workflow in progress: \(workflow).")
        }

        if let application = graph.entities.first(where: { $0.kind == .application }) {
            parts.append("Reopen focus: \(application.title).")
        }

        if let lastExchange = authorizedInput.recentConversationExchanges.last {
            parts.append("Last topic you raised: “\(lastExchange.userTranscript)”.")
        }

        if parts.isEmpty {
            return "I don't have enough saved project context to resume. Tell me the task or say “my current task is …”."
        }

        return parts.joined(separator: " ")
    }

    private static func catchMeUp(
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> String {
        var lines: [String] = ["Here's a quick catch-up from authorized Dexter context only:"]

        if let task = graph.entities.first(where: { $0.kind == .task })?.detail {
            lines.append("- Task: \(task)")
        }
        if let workflow = graph.entities.first(where: { $0.kind == .workflow })?.detail {
            lines.append("- Workflow: \(workflow)")
        }
        if let application = graph.entities.first(where: { $0.kind == .application }) {
            lines.append("- Application: \(application.title)\(application.detail.map { " — \($0)" } ?? "")")
        }

        let memorySnippets = graph.entities.filter { $0.kind == .memory || $0.kind == .preference }.prefix(3)
        for memoryEntity in memorySnippets {
            lines.append("- Memory: \(memoryEntity.detail ?? memoryEntity.title)")
        }

        if let lastExchange = authorizedInput.recentConversationExchanges.last {
            lines.append("- Last message: “\(lastExchange.userTranscript)”")
        }

        if lines.count == 1 {
            return "I don't have much authorized context stored yet. Use “remember that …” or set your current task and ask again."
        }

        return lines.joined(separator: "\n")
    }

    private static func whatShouldIDoNext(
        graph: DexterPersonalContextGraphSnapshot,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> String {
        if let commitment = graph.entities.first(where: { $0.kind == .commitment })?.detail?.nonEmptyTrimmedValue {
            return "Based on your saved commitment, next up: \(commitment)."
        }

        if let goal = graph.entities.first(where: { $0.kind == .goal })?.detail?.nonEmptyTrimmedValue {
            return "Your stated goal is “\(goal)”. Pick the next step that moves that forward."
        }

        if let task = graph.entities.first(where: { $0.kind == .task })?.detail?.nonEmptyTrimmedValue {
            return "Continue your current task: \(task)."
        }

        if let workflow = graph.entities.first(where: { $0.kind == .workflow })?.detail?.nonEmptyTrimmedValue {
            return "Continue the “\(workflow)” workflow from where you stopped."
        }

        if let lastExchange = authorizedInput.recentConversationExchanges.last {
            return "I only have your last message (“\(lastExchange.userTranscript)”). Tell me the outcome you want and I can suggest a next step."
        }

        return "I don't have enough project/task context to recommend a next step. Set your task or remember your goal first."
    }
}
