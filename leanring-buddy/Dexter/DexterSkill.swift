//
//  DexterSkill.swift
//  leanring-buddy
//
//  Skills describe reusable capability bundles. They do not execute independently —
//  Dexter routes them through Context → Intent → Planner → Permission → Tool Gateway → … → Memory.
//

import Foundation

enum DexterSkillIdentifier: String, Codable, Equatable, CaseIterable {
    case coding = "coding"
    case research = "research"
    case browserResearch = "browser_research"
    case fileOrganization = "file_organization"
    case study = "study"
    case productivity = "productivity"
    case developmentEnvironment = "development_environment"
}

/// Canonical pipeline shared by skills, workflows, and proactive automations (single runtime).
enum DexterSkillPipelinePhase: String, Codable, Equatable, CaseIterable {
    case skill = "SKILL"
    case trigger = "TRIGGER"
    case context = "CONTEXT"
    case intent = "INTENT"
    case plan = "PLAN"
    case policy = "POLICY"
    case toolGateway = "TOOL_GATEWAY"
    case execute = "EXECUTE"
    case verify = "VERIFY"
    case memory = "MEMORY"
}

struct DexterSkillInput: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let isRequired: Bool
}

struct DexterSkillTrigger: Codable, Equatable {
    let phrases: [String]
    /// When set, boosts resolution when the structured intent kind matches.
    let alignedIntentKinds: [DexterIntentKind]
}

struct DexterSkillWorkflowBinding: Codable, Equatable {
    /// Optional link to a reusable `DexterLearnedWorkflow.workflowIdentifier`.
    let workflowIdentifier: String?
}

struct DexterSkillVerification: Codable, Equatable {
    let policy: String
    let expectedStates: [String]
    let stopOnUncertainty: Bool
}

struct DexterSkillMemoryRequirements: Codable, Equatable {
    let includePersistentMemoryInContext: Bool
    let includePersonalContextGraph: Bool
    let includeCurrentTask: Bool
    let memoryRecallLimit: Int
    let preferredMemoryTypes: [String]
}

struct DexterSkill: Codable, Equatable, Identifiable {
    let id: DexterSkillIdentifier
    let name: String
    let description: String
    let trigger: DexterSkillTrigger
    let inputs: [DexterSkillInput]
    let requiredCapabilities: [String]
    let permissions: [String]
    let workflow: DexterSkillWorkflowBinding
    let verification: DexterSkillVerification
    let memoryRequirements: DexterSkillMemoryRequirements
    let owner: String
    let version: String
    /// Future composition: skills that may be chained with this one in later releases.
    let composableWithSkillIds: [DexterSkillIdentifier]
}

struct DexterSkillResolution: Equatable {
    let skill: DexterSkill
    let confidence: Double
}

struct DexterSkillEngineResult: Equatable {
    let matchedSkill: DexterSkill?
    let matchConfidence: Double
    let mergedIntentPlan: DexterIntentPlan?
    let pipelinePhases: [DexterSkillPipelinePhase]
}
