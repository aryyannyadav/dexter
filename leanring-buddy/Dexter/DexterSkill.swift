//
//  DexterSkill.swift
//  leanring-buddy
//

import Foundation

/// Future marketplace/SDK surface. Skills are not executed directly — Dexter maps them to typed actions + OpenClaw.
struct DexterSkillDefinition: Equatable, Identifiable {
    let id: String
    let displayName: String
    let description: String
    let triggerPhrases: [String]
    let requiredOpenClawCapabilities: [String]
    let defaultRiskLevel: DexterActionRiskLevel
}

enum DexterBuiltInSkillCatalog {
    static let codingEnvironment = DexterSkillDefinition(
        id: "coding-environment",
        displayName: "Development Environment",
        description: "Prepare a coding workspace with approved applications and editor fixes.",
        triggerPhrases: ["prepare my coding environment"],
        requiredOpenClawCapabilities: ["computer.act"],
        defaultRiskLevel: .moderateRisk
    )

    static let browserResearch = DexterSkillDefinition(
        id: "browser-research",
        displayName: "Browser Research",
        description: "Navigate and inspect browser pages through OpenClaw browser capabilities.",
        triggerPhrases: ["search the web for"],
        requiredOpenClawCapabilities: ["browser.proxy", "computer.act"],
        defaultRiskLevel: .lowRisk
    )
}
