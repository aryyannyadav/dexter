//
//  DexterWorkflowCatalog.swift
//  leanring-buddy
//

import Foundation

enum DexterWorkflowCatalog {
    static let prepareCodingEnvironmentIdentifier = "prepare_coding_environment_v1"

    static func allWorkflows() -> [DexterLearnedWorkflow] {
        [prepareCodingEnvironmentWorkflow()]
    }

    static func workflow(forIdentifier identifier: String) -> DexterLearnedWorkflow? {
        allWorkflows().first { $0.workflowIdentifier == identifier }
    }

    static func workflowMatchingTrigger(userMessage: String) -> DexterLearnedWorkflow? {
        let normalized = normalize(userMessage)
        return allWorkflows().first { workflow in
            workflow.triggerPhrases.contains { normalized.contains(normalize($0)) }
        }
    }

    private static func prepareCodingEnvironmentWorkflow() -> DexterLearnedWorkflow {
        let defaultContextRequirements = DexterWorkflowContextRequirements(
            requiresAccessibilityPermission: false,
            requiresApplicationLifecycleProbe: true,
            requiresBrowserState: false,
            requiredContextSections: ["activeApplication"]
        )

        let steps: [DexterWorkflowStepDefinition] = [
            DexterWorkflowStepDefinition(
                id: UUID(),
                title: "Open VS Code",
                instruction: "Launch Visual Studio Code.",
                actionKind: .openApplication,
                parameters: ["applicationName": "Visual Studio Code"],
                verification: DexterWorkflowStepVerification(
                    strategy: "application_running",
                    expectedValue: "Visual Studio Code"
                ),
                contextRequirements: defaultContextRequirements,
                requiredPermissions: []
            ),
            DexterWorkflowStepDefinition(
                id: UUID(),
                title: "Open project",
                instruction: "Open your project folder in VS Code (Dexter will not click stale coordinates). Say continue when the project is open.",
                actionKind: .waitForUserConfirmation,
                parameters: [:],
                verification: DexterWorkflowStepVerification(
                    strategy: "user_confirmed",
                    expectedValue: nil
                ),
                contextRequirements: DexterWorkflowContextRequirements(
                    requiresAccessibilityPermission: false,
                    requiresApplicationLifecycleProbe: true,
                    requiresBrowserState: false,
                    requiredContextSections: ["activeApplication", "activeWindow"]
                ),
                requiredPermissions: []
            ),
            DexterWorkflowStepDefinition(
                id: UUID(),
                title: "Terminal check",
                instruction: "Capture an approved terminal inspect command in the project area.",
                actionKind: .runTerminalInspect,
                parameters: [
                    "commandTemplate": "inspect_pwd",
                    "workingDirectory": "~/Documents"
                ],
                verification: DexterWorkflowStepVerification(
                    strategy: "terminal_output_nonempty",
                    expectedValue: nil
                ),
                contextRequirements: defaultContextRequirements,
                requiredPermissions: ["filesystem"]
            ),
            DexterWorkflowStepDefinition(
                id: UUID(),
                title: "Start server",
                instruction: "Start your dev server manually. Dexter only runs approved command templates — say continue when the server is running, or tell me to stop.",
                actionKind: .waitForUserConfirmation,
                parameters: ["confirmationKey": "server_running"],
                verification: DexterWorkflowStepVerification(
                    strategy: "user_confirmed",
                    expectedValue: "server_running"
                ),
                contextRequirements: defaultContextRequirements,
                requiredPermissions: []
            ),
            DexterWorkflowStepDefinition(
                id: UUID(),
                title: "Open browser",
                instruction: "Open the local app URL in the browser (no stored click coordinates).",
                actionKind: .browserNavigate,
                parameters: ["url": "http://127.0.0.1:3000", "verificationHint": "127.0.0.1"],
                verification: DexterWorkflowStepVerification(
                    strategy: "browser_url_contains",
                    expectedValue: "127.0.0.1"
                ),
                contextRequirements: DexterWorkflowContextRequirements(
                    requiresAccessibilityPermission: false,
                    requiresApplicationLifecycleProbe: false,
                    requiresBrowserState: true,
                    requiredContextSections: ["browser"]
                ),
                requiredPermissions: []
            ),
            DexterWorkflowStepDefinition(
                id: UUID(),
                title: "Verify server",
                instruction: "Confirm the browser shows the running server.",
                actionKind: .askUserWhenUncertain,
                parameters: [
                    "prompt": "Does the browser show your app responding? Say yes to finish or describe what looks wrong."
                ],
                verification: DexterWorkflowStepVerification(
                    strategy: "user_confirmed",
                    expectedValue: nil
                ),
                contextRequirements: DexterWorkflowContextRequirements(
                    requiresAccessibilityPermission: false,
                    requiresApplicationLifecycleProbe: false,
                    requiresBrowserState: true,
                    requiredContextSections: ["browser"]
                ),
                requiredPermissions: []
            )
        ]

        return DexterLearnedWorkflow(
            id: UUID(),
            workflowIdentifier: prepareCodingEnvironmentIdentifier,
            name: "Prepare my coding environment",
            triggerPhrases: [
                "prepare my coding environment",
                "set up my coding environment",
                "get my dev environment ready"
            ],
            conditions: [
                DexterWorkflowCondition(kind: "agent_runtime_available", parameter: nil)
            ],
            contextRequirements: defaultContextRequirements,
            steps: steps,
            permissions: ["accessibility", "filesystem"],
            verificationPolicy: "action_pipeline_verify",
            owner: "dexter",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
