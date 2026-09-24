//
//  DexterSkillCatalog.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillCatalog {
    static func allSkills() -> [DexterSkill] {
        [
            codingSkill(),
            researchSkill(),
            browserResearchSkill(),
            fileOrganizationSkill(),
            studySkill(),
            productivitySkill(),
            developmentEnvironmentSkill()
        ]
    }

    static func skill(forIdentifier identifier: DexterSkillIdentifier) -> DexterSkill? {
        allSkills().first { $0.id == identifier }
    }

    private static func codingSkill() -> DexterSkill {
        DexterSkill(
            id: .coding,
            name: "Coding",
            description: "Help with code, errors, and editor context using verified actions when needed.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "help me code",
                    "coding question",
                    "fix this error",
                    "debug this",
                    "why is my code"
                ],
                alignedIntentKinds: [.fix, .explain, .ask]
            ),
            inputs: [
                DexterSkillInput(
                    id: "error_or_goal",
                    title: "Error or goal",
                    description: "What you are trying to build or what failed.",
                    isRequired: false
                )
            ],
            requiredCapabilities: ["computer.act", "file.read"],
            permissions: ["accessibility", "screenRecording"],
            workflow: DexterSkillWorkflowBinding(workflowIdentifier: nil),
            verification: DexterSkillVerification(
                policy: "action_pipeline_verify",
                expectedStates: ["error_cleared_or_explained"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: true,
                includePersonalContextGraph: true,
                includeCurrentTask: true,
                memoryRecallLimit: 6,
                preferredMemoryTypes: ["PREFERENCE", "FACT", "EPISODIC"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.research, .developmentEnvironment]
        )
    }

    private static func researchSkill() -> DexterSkill {
        DexterSkill(
            id: .research,
            name: "Research",
            description: "Summarize and compare information from context and memory without unsafe automation.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "research",
                    "look up",
                    "summarize this",
                    "compare",
                    "what do you know about"
                ],
                alignedIntentKinds: [.search, .summarize, .compare, .ask, .explain]
            ),
            inputs: [
                DexterSkillInput(
                    id: "topic",
                    title: "Topic",
                    description: "What to research or summarize.",
                    isRequired: true
                )
            ],
            requiredCapabilities: [],
            permissions: [],
            workflow: DexterSkillWorkflowBinding(workflowIdentifier: nil),
            verification: DexterSkillVerification(
                policy: "information_only",
                expectedStates: ["grounded_answer"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: true,
                includePersonalContextGraph: false,
                includeCurrentTask: false,
                memoryRecallLimit: 8,
                preferredMemoryTypes: ["FACT", "EPISODIC"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.browserResearch]
        )
    }

    private static func browserResearchSkill() -> DexterSkill {
        DexterSkill(
            id: .browserResearch,
            name: "BrowserResearch",
            description: "Navigate and read the web through the tool gateway with post-action verification.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "search the web for",
                    "open youtube",
                    "go to",
                    "read this page",
                    "browser"
                ],
                alignedIntentKinds: [.search, .open, .find]
            ),
            inputs: [
                DexterSkillInput(
                    id: "query_or_url",
                    title: "Query or URL",
                    description: "What to open or search for.",
                    isRequired: true
                )
            ],
            requiredCapabilities: ["browser.proxy", "computer.act"],
            permissions: ["accessibility"],
            workflow: DexterSkillWorkflowBinding(workflowIdentifier: nil),
            verification: DexterSkillVerification(
                policy: "browser_verification_engine",
                expectedStates: ["url_or_title_evidence"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: false,
                includePersonalContextGraph: true,
                includeCurrentTask: false,
                memoryRecallLimit: 4,
                preferredMemoryTypes: ["EPISODIC"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.research]
        )
    }

    private static func fileOrganizationSkill() -> DexterSkill {
        DexterSkill(
            id: .fileOrganization,
            name: "FileOrganization",
            description: "Find, read, and organize files in approved folders with policy-gated tools.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "organize my files",
                    "find my document",
                    "move this file",
                    "search my downloads",
                    "file in documents"
                ],
                alignedIntentKinds: [.find, .edit, .create, .open]
            ),
            inputs: [
                DexterSkillInput(
                    id: "path_or_name",
                    title: "Path or name",
                    description: "File name, folder, or description of what to find.",
                    isRequired: false
                )
            ],
            requiredCapabilities: ["file.search", "file.read", "file.move"],
            permissions: ["filesystem"],
            workflow: DexterSkillWorkflowBinding(workflowIdentifier: nil),
            verification: DexterSkillVerification(
                policy: "file_verification_engine",
                expectedStates: ["path_exists_or_absent_as_expected"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: true,
                includePersonalContextGraph: true,
                includeCurrentTask: false,
                memoryRecallLimit: 4,
                preferredMemoryTypes: ["FACT", "WORKFLOW"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.productivity]
        )
    }

    private static func studySkill() -> DexterSkill {
        DexterSkill(
            id: .study,
            name: "Study",
            description: "Step-by-step teaching and explanations grounded in what is on screen.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "teach me",
                    "help me learn",
                    "study",
                    "walk me through",
                    "explain step by step"
                ],
                alignedIntentKinds: [.teach, .explain, .plan]
            ),
            inputs: [
                DexterSkillInput(
                    id: "topic",
                    title: "Topic",
                    description: "What you want to learn.",
                    isRequired: false
                )
            ],
            requiredCapabilities: [],
            permissions: ["screenRecording"],
            workflow: DexterSkillWorkflowBinding(workflowIdentifier: nil),
            verification: DexterSkillVerification(
                policy: "teaching_step_verify",
                expectedStates: ["user_confirmed_step"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: true,
                includePersonalContextGraph: false,
                includeCurrentTask: true,
                memoryRecallLimit: 4,
                preferredMemoryTypes: ["PREFERENCE", "COMMITMENT"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.research, .coding]
        )
    }

    private static func productivitySkill() -> DexterSkill {
        DexterSkill(
            id: .productivity,
            name: "Productivity",
            description: "Tasks, reminders, and personal context catch-up without fabricating project state.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "what's next",
                    "catch me up",
                    "where was i",
                    "remind me",
                    "my task"
                ],
                alignedIntentKinds: [.plan, .remind, .remember, .ask, .companion]
            ),
            inputs: [],
            requiredCapabilities: [],
            permissions: [],
            workflow: DexterSkillWorkflowBinding(workflowIdentifier: nil),
            verification: DexterSkillVerification(
                policy: "memory_and_graph_only",
                expectedStates: ["grounded_personal_context"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: true,
                includePersonalContextGraph: true,
                includeCurrentTask: true,
                memoryRecallLimit: 10,
                preferredMemoryTypes: ["TASK", "COMMITMENT", "WORKFLOW", "FACT"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.fileOrganization, .developmentEnvironment]
        )
    }

    private static func developmentEnvironmentSkill() -> DexterSkill {
        DexterSkill(
            id: .developmentEnvironment,
            name: "DevelopmentEnvironment",
            description: "Prepare a coding workspace via the reusable development-environment workflow.",
            trigger: DexterSkillTrigger(
                phrases: [
                    "prepare my coding environment",
                    "set up my coding environment",
                    "get my dev environment ready"
                ],
                alignedIntentKinds: [.plan, .automate, .run, .open]
            ),
            inputs: [],
            requiredCapabilities: ["computer.act", "browser.proxy", "terminal.inspect"],
            permissions: ["accessibility", "filesystem"],
            workflow: DexterSkillWorkflowBinding(
                workflowIdentifier: DexterWorkflowCatalog.prepareCodingEnvironmentIdentifier
            ),
            verification: DexterSkillVerification(
                policy: "workflow_step_verify",
                expectedStates: ["action_verified", "user_confirmed"],
                stopOnUncertainty: true
            ),
            memoryRequirements: DexterSkillMemoryRequirements(
                includePersistentMemoryInContext: true,
                includePersonalContextGraph: true,
                includeCurrentTask: true,
                memoryRecallLimit: 6,
                preferredMemoryTypes: ["WORKFLOW", "PREFERENCE"]
            ),
            owner: "dexter",
            version: "1.0.0",
            composableWithSkillIds: [.coding, .productivity]
        )
    }
}
