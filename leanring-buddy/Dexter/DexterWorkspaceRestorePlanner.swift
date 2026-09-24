//
//  DexterWorkspaceRestorePlanner.swift
//  leanring-buddy
//

import Foundation

struct DexterWorkspaceCurrentState: Equatable {
    let authorizedInput: DexterAuthorizedPersonalContextInput
    let personalContextGraph: DexterPersonalContextGraphSnapshot
    let accountabilitySnapshot: DexterAccountabilityTaskSnapshot
}

struct DexterWorkspaceRestoreGap: Equatable {
    let category: String
    let desiredSummary: String
    let currentSummary: String
}

struct DexterWorkspaceRestoreComparison: Equatable {
    let alignedSummaries: [String]
    let gaps: [DexterWorkspaceRestoreGap]
}

enum DexterWorkspaceRestoreStepKind: Equatable {
    case restoreTaskMemory
    case restoreAccountabilityTaskFocus
    case openApplication
    case focusApplication
    case openBrowserURL
    case informUser
}

struct DexterWorkspaceRestoreStep: Equatable, Identifiable {
    let id: UUID
    let kind: DexterWorkspaceRestoreStepKind
    let humanReadableDescription: String
    let proposedAction: DexterAction?
    let accountabilityTaskIdentifier: UUID?
    let taskDescriptionToRestore: String?

    init(
        id: UUID = UUID(),
        kind: DexterWorkspaceRestoreStepKind,
        humanReadableDescription: String,
        proposedAction: DexterAction? = nil,
        accountabilityTaskIdentifier: UUID? = nil,
        taskDescriptionToRestore: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.humanReadableDescription = humanReadableDescription
        self.proposedAction = proposedAction
        self.accountabilityTaskIdentifier = accountabilityTaskIdentifier
        self.taskDescriptionToRestore = taskDescriptionToRestore
    }
}

enum DexterWorkspaceRestorePlanner {
    static func compare(
        desiredSnapshot: DexterWorkspaceSnapshot,
        currentState: DexterWorkspaceCurrentState
    ) -> DexterWorkspaceRestoreComparison {
        let authorizedInput = currentState.authorizedInput
        var aligned: [String] = []
        var gaps: [DexterWorkspaceRestoreGap] = []

        if DexterWorkspaceSemanticMatching.applicationsMatch(
            saved: desiredSnapshot.frontmostApplication,
            currentDisplayName: authorizedInput.activeApplicationName,
            currentBundleIdentifier: authorizedInput.activeApplicationBundleIdentifier
        ) {
            if let name = desiredSnapshot.frontmostApplication?.displayName {
                aligned.append("Frontmost app already matches \(name).")
            }
        } else if let desiredApplication = desiredSnapshot.frontmostApplication {
            gaps.append(
                DexterWorkspaceRestoreGap(
                    category: "application",
                    desiredSummary: desiredApplication.displayName,
                    currentSummary: authorizedInput.activeApplicationName ?? "unknown"
                )
            )
        }

        if DexterWorkspaceSemanticMatching.browserTabsMatch(
            saved: desiredSnapshot.browserTab,
            currentPageURL: authorizedInput.browserPageURL,
            currentPageTitle: authorizedInput.browserPageTitle
        ) {
            if let url = desiredSnapshot.browserTab?.pageURL ?? desiredSnapshot.browserTab?.pageTitle {
                aligned.append("Browser tab already matches \(url).")
            }
        } else if let browserTab = desiredSnapshot.browserTab,
                  browserTab.pageURL?.nonEmptyTrimmedValue != nil
                    || browserTab.pageTitle?.nonEmptyTrimmedValue != nil {
            gaps.append(
                DexterWorkspaceRestoreGap(
                    category: "browser",
                    desiredSummary: browserTab.pageURL ?? browserTab.pageTitle ?? "saved tab",
                    currentSummary: authorizedInput.browserPageURL ?? authorizedInput.browserPageTitle ?? "none"
                )
            )
        }

        if let savedTask = desiredSnapshot.activeTaskDescription?.nonEmptyTrimmedValue {
            let currentTask = authorizedInput.currentTaskDescription?.nonEmptyTrimmedValue
            if currentTask == savedTask {
                aligned.append("Active task memory already matches.")
            } else {
                gaps.append(
                    DexterWorkspaceRestoreGap(
                        category: "task_memory",
                        desiredSummary: savedTask,
                        currentSummary: currentTask ?? "none"
                    )
                )
            }
        }

        if let savedAccountabilityIdentifier = desiredSnapshot.activeAccountabilityTaskIdentifier {
            let currentIdentifier = currentState.accountabilitySnapshot.activeTask?.id
            if currentIdentifier == savedAccountabilityIdentifier {
                aligned.append("Accountability task focus already matches.")
            } else {
                gaps.append(
                    DexterWorkspaceRestoreGap(
                        category: "accountability_task",
                        desiredSummary: desiredSnapshot.activeAccountabilityTaskTitle ?? savedAccountabilityIdentifier.uuidString,
                        currentSummary: currentState.accountabilitySnapshot.activeTask?.title ?? "none"
                    )
                )
            }
        }

        if let savedWindow = desiredSnapshot.foregroundWindow,
           !DexterWorkspaceSemanticMatching.windowTitlesMatch(
               saved: savedWindow,
               currentTitle: authorizedInput.activeWindowTitle
           ) {
            gaps.append(
                DexterWorkspaceRestoreGap(
                    category: "window",
                    desiredSummary: savedWindow.windowTitle,
                    currentSummary: authorizedInput.activeWindowTitle ?? "unknown"
                )
            )
        } else if desiredSnapshot.foregroundWindow != nil {
            aligned.append("Foreground window title looks aligned.")
        }

        if let project = desiredSnapshot.project,
           let fileName = project.activeFileName?.nonEmptyTrimmedValue {
            let currentFile = currentState.personalContextGraph.entities
                .first(where: { $0.id == "vscode:file" })?.title
            if currentFile?.lowercased() != fileName.lowercased() {
                gaps.append(
                    DexterWorkspaceRestoreGap(
                        category: "project_file",
                        desiredSummary: fileName,
                        currentSummary: currentFile ?? "not in editor"
                    )
                )
            } else {
                aligned.append("Editor file name matches \(fileName).")
            }
        }

        return DexterWorkspaceRestoreComparison(alignedSummaries: aligned, gaps: gaps)
    }

    static func planSteps(
        desiredSnapshot: DexterWorkspaceSnapshot,
        comparison: DexterWorkspaceRestoreComparison
    ) -> [DexterWorkspaceRestoreStep] {
        var steps: [DexterWorkspaceRestoreStep] = []
        let gapCategoryOrder = [
            "task_memory",
            "accountability_task",
            "application",
            "browser",
            "window",
            "project_file"
        ]

        for category in gapCategoryOrder {
            for gap in comparison.gaps where gap.category == category {
            switch gap.category {
            case "task_memory":
                if let taskDescription = desiredSnapshot.activeTaskDescription?.nonEmptyTrimmedValue {
                    steps.append(
                        DexterWorkspaceRestoreStep(
                            kind: .restoreTaskMemory,
                            humanReadableDescription: "Restore your active task memory to “\(taskDescription)”.",
                            taskDescriptionToRestore: taskDescription
                        )
                    )
                }

            case "accountability_task":
                if let identifier = desiredSnapshot.activeAccountabilityTaskIdentifier {
                    let title = desiredSnapshot.activeAccountabilityTaskTitle ?? "your saved task"
                    steps.append(
                        DexterWorkspaceRestoreStep(
                            kind: .restoreAccountabilityTaskFocus,
                            humanReadableDescription: "Focus accountability task “\(title)”.",
                            accountabilityTaskIdentifier: identifier
                        )
                    )
                }

            case "application":
                if let application = desiredSnapshot.frontmostApplication {
                    let openAction = DexterActionFactory.openApplication(
                        named: application.displayName,
                        contextSummary: "Workspace restore: bring \(application.displayName) forward."
                    )
                    steps.append(
                        DexterWorkspaceRestoreStep(
                            kind: .openApplication,
                            humanReadableDescription: "Open \(application.displayName) (semantic app restore, not coordinate replay).",
                            proposedAction: openAction
                        )
                    )
                }

            case "browser":
                if let url = desiredSnapshot.browserTab?.pageURL?.nonEmptyTrimmedValue {
                    let hint = desiredSnapshot.browserTab?.pageTitle ?? url
                    let browserAction = DexterActionFactory.browserOpen(url: url, verificationHint: hint)
                    steps.append(
                        DexterWorkspaceRestoreStep(
                            kind: .openBrowserURL,
                            humanReadableDescription: "Open saved browser destination \(hint).",
                            proposedAction: browserAction
                        )
                    )
                }

            case "window":
                if let savedWindow = desiredSnapshot.foregroundWindow {
                    steps.append(
                        DexterWorkspaceRestoreStep(
                            kind: .informUser,
                            humanReadableDescription:
                                "After apps are restored, reopen window “\(savedWindow.windowTitle)” if it is not already visible."
                        )
                    )
                }

            case "project_file":
                if let fileName = desiredSnapshot.project?.activeFileName?.nonEmptyTrimmedValue {
                    let workspaceName = desiredSnapshot.project?.workspaceName?.nonEmptyTrimmedValue
                    let detail = workspaceName.map { " in \($0)" } ?? ""
                    steps.append(
                        DexterWorkspaceRestoreStep(
                            kind: .informUser,
                            humanReadableDescription:
                                "Reopen \(fileName)\(detail) in your editor—Dexter restores apps and URLs, not stale click positions."
                        )
                    )
                }

            default:
                continue
            }
            }
        }

        if !comparison.gaps.isEmpty {
            for fileReference in desiredSnapshot.relevantFiles where fileReference.absolutePath != nil {
                let path = fileReference.absolutePath!
                steps.append(
                    DexterWorkspaceRestoreStep(
                        kind: .informUser,
                        humanReadableDescription: "Reopen file at \(path) when you are ready."
                    )
                )
            }
        }

        return deduplicatedSteps(steps)
    }

    static func planSummaryText(
        desiredSnapshot: DexterWorkspaceSnapshot,
        comparison: DexterWorkspaceRestoreComparison,
        steps: [DexterWorkspaceRestoreStep]
    ) -> String {
        let capturedDescription = desiredSnapshot.capturedAt.formatted(date: .abbreviated, time: .shortened)
        var lines = [
            "I inspected your current workspace and compared it to the snapshot from \(capturedDescription)."
        ]

        if !comparison.alignedSummaries.isEmpty {
            lines.append("Already aligned: \(comparison.alignedSummaries.joined(separator: " "))")
        }

        if comparison.gaps.isEmpty && steps.isEmpty {
            lines.append("Everything important already matches—no restore actions needed.")
            return lines.joined(separator: " ")
        }

        if !comparison.gaps.isEmpty {
            let gapDescriptions = comparison.gaps.map { gap in
                "\(gap.category): want \(gap.desiredSummary), currently \(gap.currentSummary)"
            }
            lines.append("Gaps: \(gapDescriptions.joined(separator: "; ")).")
        }

        if !steps.isEmpty {
            let stepDescriptions = steps.map(\.humanReadableDescription)
            lines.append("Plan: \(stepDescriptions.joined(separator: " Then, "))")
        }

        return lines.joined(separator: " ")
    }

    private static func deduplicatedSteps(_ steps: [DexterWorkspaceRestoreStep]) -> [DexterWorkspaceRestoreStep] {
        var seenDescriptions: Set<String> = []
        var result: [DexterWorkspaceRestoreStep] = []
        for step in steps {
            let key = "\(step.kind)-\(step.humanReadableDescription)"
            if seenDescriptions.insert(key).inserted {
                result.append(step)
            }
        }
        return result
    }
}
