//
//  DexterSkillEngineLog.swift
//  leanring-buddy
//

import Foundation

enum DexterSkillEngineLog {
    static func logResolved(skill: DexterSkill, confidence: Double) {
        print("[DEXTER][SKILL] resolved id=\(skill.id.rawValue) confidence=\(String(format: "%.2f", confidence))")
    }

    static func logNoMatch() {
        print("[DEXTER][SKILL] no skill matched")
    }
}
