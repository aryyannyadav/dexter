//
//  DexterWorkspaceSnapshotCapture.swift
//  leanring-buddy
//

import Foundation

enum DexterWorkspaceSnapshotCapture {
    static func capture(
        authorizedInput: DexterAuthorizedPersonalContextInput,
        personalContextGraph: DexterPersonalContextGraphSnapshot,
        accountabilitySnapshot: DexterAccountabilityTaskSnapshot
    ) -> DexterWorkspaceSnapshot {
        let frontmostApplication = makeFrontmostApplicationReference(from: authorizedInput)
        let foregroundWindow = makeForegroundWindowReference(from: authorizedInput)
        let openApplications = collectOpenApplicationReferences(
            authorizedInput: authorizedInput,
            graph: personalContextGraph
        )
        let browserTab = makeBrowserTabReference(from: authorizedInput)
        let project = makeProjectReference(from: authorizedInput, graph: personalContextGraph)
        let relevantFiles = collectRelevantFileReferences(
            authorizedInput: authorizedInput,
            graph: personalContextGraph
        )

        let activeAccountabilityTask = accountabilitySnapshot.activeTask

        return DexterWorkspaceSnapshot(
            capturedAt: Date(),
            label: nil,
            frontmostApplication: frontmostApplication,
            foregroundWindow: foregroundWindow,
            openApplications: openApplications,
            browserTab: browserTab,
            project: project,
            activeTaskDescription: authorizedInput.currentTaskDescription?.nonEmptyTrimmedValue,
            activeAccountabilityTaskIdentifier: activeAccountabilityTask?.id,
            activeAccountabilityTaskTitle: activeAccountabilityTask?.title,
            workflowSummary: authorizedInput.workflowSummary?.nonEmptyTrimmedValue,
            relevantFiles: relevantFiles
        )
    }

    static func userFacingSaveSummary(snapshot: DexterWorkspaceSnapshot) -> String {
        var lines = ["I saved a semantic workspace snapshot (no screen coordinates)."]
        if let application = snapshot.frontmostApplication {
            lines.append("Frontmost app: \(application.displayName).")
        }
        if let browserTab = snapshot.browserTab,
           let url = browserTab.pageURL?.nonEmptyTrimmedValue ?? browserTab.pageTitle?.nonEmptyTrimmedValue {
            lines.append("Browser context: \(url).")
        }
        if let project = snapshot.project {
            let projectPieces = [project.activeFileName, project.workspaceName].compactMap { $0?.nonEmptyTrimmedValue }
            if !projectPieces.isEmpty {
                lines.append("Project: \(projectPieces.joined(separator: " in ")).")
            }
        }
        if let task = snapshot.activeTaskDescription?.nonEmptyTrimmedValue {
            lines.append("Active task memory: \(task).")
        }
        if let accountabilityTitle = snapshot.activeAccountabilityTaskTitle?.nonEmptyTrimmedValue {
            lines.append("Accountability task: \(accountabilityTitle).")
        }
        lines.append("Say “restore my workspace” when you want Dexter to compare and bring this back.")
        return lines.joined(separator: " ")
    }

    private static func makeFrontmostApplicationReference(
        from authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterWorkspaceApplicationReference? {
        guard let displayName = authorizedInput.activeApplicationName?.nonEmptyTrimmedValue else {
            return nil
        }
        return DexterWorkspaceApplicationReference(
            displayName: displayName,
            bundleIdentifier: authorizedInput.activeApplicationBundleIdentifier?.nonEmptyTrimmedValue
        )
    }

    private static func makeForegroundWindowReference(
        from authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterWorkspaceWindowReference? {
        guard let windowTitle = authorizedInput.activeWindowTitle?.nonEmptyTrimmedValue else {
            return nil
        }
        return DexterWorkspaceWindowReference(
            applicationDisplayName: authorizedInput.activeApplicationName?.nonEmptyTrimmedValue,
            windowTitle: windowTitle
        )
    }

    private static func makeBrowserTabReference(
        from authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterWorkspaceBrowserTabReference? {
        let pageURL = authorizedInput.browserPageURL?.nonEmptyTrimmedValue
        let pageTitle = authorizedInput.browserPageTitle?.nonEmptyTrimmedValue
        if pageURL == nil && pageTitle == nil {
            return nil
        }
        return DexterWorkspaceBrowserTabReference(
            browserApplicationName: authorizedInput.activeApplicationName?.nonEmptyTrimmedValue,
            pageTitle: pageTitle,
            pageURL: pageURL
        )
    }

    private static func makeProjectReference(
        from authorizedInput: DexterAuthorizedPersonalContextInput,
        graph: DexterPersonalContextGraphSnapshot
    ) -> DexterWorkspaceProjectReference? {
        let workspaceName = graph.entities.first(where: { $0.id == "vscode:workspace" })?.title
        let fileName = graph.entities.first(where: { $0.id == "vscode:file" })?.title
        let workflowSummary = authorizedInput.workflowSummary?.nonEmptyTrimmedValue

        if workspaceName == nil && fileName == nil && workflowSummary == nil {
            return nil
        }

        return DexterWorkspaceProjectReference(
            workspaceName: workspaceName?.nonEmptyTrimmedValue,
            activeFileName: fileName?.nonEmptyTrimmedValue,
            editorApplicationName: authorizedInput.activeApplicationName?.nonEmptyTrimmedValue
        )
    }

    private static func collectOpenApplicationReferences(
        authorizedInput: DexterAuthorizedPersonalContextInput,
        graph: DexterPersonalContextGraphSnapshot
    ) -> [DexterWorkspaceApplicationReference] {
        var references: [DexterWorkspaceApplicationReference] = []
        if let frontmost = makeFrontmostApplicationReference(from: authorizedInput) {
            references.append(frontmost)
        }

        for entity in graph.entities where entity.kind == .application {
            let displayName = entity.title.nonEmptyTrimmedValue ?? entity.id
            let bundleIdentifier: String? = {
                if entity.id == "application:vscode" {
                    return "com.microsoft.VSCode"
                }
                return nil
            }()
            let candidate = DexterWorkspaceApplicationReference(
                displayName: displayName,
                bundleIdentifier: bundleIdentifier
            )
            if !references.contains(where: {
                DexterWorkspaceSemanticMatching.applicationsMatch(
                    saved: $0,
                    currentDisplayName: candidate.displayName,
                    currentBundleIdentifier: candidate.bundleIdentifier
                )
            }) {
                references.append(candidate)
            }
        }

        return references
    }

    private static func collectRelevantFileReferences(
        authorizedInput: DexterAuthorizedPersonalContextInput,
        graph: DexterPersonalContextGraphSnapshot
    ) -> [DexterWorkspaceFileReference] {
        var files: [DexterWorkspaceFileReference] = []

        if let vscodeFileName = graph.entities.first(where: { $0.id == "vscode:file" })?.title.nonEmptyTrimmedValue {
            files.append(DexterWorkspaceFileReference(displayName: vscodeFileName, absolutePath: nil))
        }

        for memory in authorizedInput.retrievedMemories {
            let candidatePaths = extractApprovedPaths(from: memory.content)
            for path in candidatePaths {
                let displayName = URL(fileURLWithPath: path).lastPathComponent
                let fileReference = DexterWorkspaceFileReference(displayName: displayName, absolutePath: path)
                if !files.contains(fileReference) {
                    files.append(fileReference)
                }
            }
        }

        return files
    }

    private static func extractApprovedPaths(from text: String) -> [String] {
        let pattern = #"(\~/[^\s\"']+|/Users/[^\s\"']+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        var paths: [String] = []
        for match in matches {
            guard let swiftRange = Range(match.range(at: 1), in: text) else { continue }
            let rawPath = String(text[swiftRange])
            switch DexterApprovedFilePathPolicy.evaluate(path: rawPath) {
            case .approved:
                paths.append(rawPath)
            case .rejected:
                continue
            }
        }
        return paths
    }
}
