//
//  DexterFileWorkspaceContextProvider.swift
//  leanring-buddy
//

import Foundation

enum DexterFileWorkspaceContextProvider {
    static let maxRelevantFilesInPrompt = 5
    static let maxSnippetCharactersInPrompt = 600

    static func attachWorkspaceContext(
        to context: DexterContext,
        profileId: UUID,
        userMessage: String,
        store: DexterFileWorkspaceStore
    ) -> DexterContext {
        guard let workspace = store.workspace(forProfileId: profileId), workspace.hasAnyLocation else {
            return context
        }

        let snapshot = store.indexSnapshot(forWorkspaceId: workspace.id)
        let editorFileName = activeEditorFileName(from: context)
        let relevantFiles = selectRelevantFiles(
            userMessage: userMessage,
            snapshot: snapshot,
            editorFileName: editorFileName,
            limit: maxRelevantFilesInPrompt
        )

        var summaryLines: [String] = []
        summaryLines.append("Workspace: \(workspace.name)")
        if let fileCount = workspace.indexedFileCount, let folderCount = workspace.indexedFolderCount,
           workspace.indexStatus == .ready {
            summaryLines.append("\(fileCount) files, \(folderCount) folders indexed")
        }
        if let git = workspace.gitSummary, git.isGitRepository {
            var gitLine = "Git repository"
            if let branch = git.branchName {
                gitLine += " — branch \(branch)"
            }
            if let status = git.shortStatusSummary {
                gitLine += " — \(status)"
            }
            summaryLines.append(gitLine)
        }
        if workspace.indexStatus == .indexing, let progress = workspace.indexProgress {
            summaryLines.append("Indexing in progress (\(Int(progress * 100))%)")
        }

        let slice = DexterFileWorkspaceContextSlice(
            workspaceId: workspace.id,
            workspaceName: workspace.name,
            indexStatus: workspace.indexStatus,
            summaryLines: summaryLines,
            relevantFiles: relevantFiles,
            matchedEditorFileName: editorFileName
        )

        return DexterContext(
            userMessage: context.userMessage,
            pointer: context.pointer,
            display: context.display,
            screen: context.screen,
            activeApplication: context.activeApplication,
            activeWindow: context.activeWindow,
            selectedText: context.selectedText,
            clipboard: context.clipboard,
            conversation: context.conversation,
            recentActions: context.recentActions,
            currentTask: context.currentTask,
            persistentMemory: context.persistentMemory,
            personalContextGraph: context.personalContextGraph,
            crossApplicationContext: context.crossApplicationContext,
            attention: context.attention,
            fileWorkspaceContext: slice
        )
    }

    static func selectRelevantFiles(
        userMessage: String,
        snapshot: DexterFileWorkspaceIndexSnapshot?,
        editorFileName: String?,
        limit: Int
    ) -> [DexterFileContext] {
        guard let snapshot, !snapshot.files.isEmpty else { return [] }

        let normalizedMessage = userMessage.lowercased()
        let tokens = normalizedMessage
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 3 }

        if let editorFileName, !editorFileName.isEmpty {
            let matches = snapshot.files.filter { $0.name.caseInsensitiveCompare(editorFileName) == .orderedSame }
            if !matches.isEmpty {
                return Array(matches.prefix(limit))
            }
        }

        if tokens.isEmpty {
            return Array(
                snapshot.files
                    .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
                    .prefix(limit)
            )
        }

        let scored = snapshot.files.map { file -> (DexterFileContext, Int) in
            var score = 0
            let haystack = (file.name + " " + file.displayPath).lowercased()
            for token in tokens where haystack.contains(token) {
                score += 2
            }
            if let snippet = file.searchableTextSnippet?.lowercased() {
                for token in tokens where snippet.contains(token) {
                    score += 1
                }
            }
            if file.contentKind == .markdown || file.name.lowercased() == "readme.md" {
                score += 1
            }
            return (file, score)
        }
        .filter { $0.1 > 0 }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return (lhs.0.modifiedAt ?? .distantPast) > (rhs.0.modifiedAt ?? .distantPast)
        }
        .map(\.0)

        if scored.isEmpty {
            return Array(
                snapshot.files
                    .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
                    .prefix(limit)
            )
        }
        return Array(scored.prefix(limit))
    }

    private static func activeEditorFileName(from context: DexterContext) -> String? {
        guard let entities = context.personalContextGraph?.entities else { return nil }
        let vscodeFile = entities.first { $0.id == "vscode:file" }
        return vscodeFile?.title
    }
}
