//
//  DexterIntent.swift
//  leanring-buddy
//
//  Structured intents exchanged between Dexter subsystems (not model action prose).
//

import Foundation

enum DexterIntentKind: String, Codable, Equatable, CaseIterable {
    case ask = "ASK"
    case explain = "EXPLAIN"
    case teach = "TEACH"
    case search = "SEARCH"
    case create = "CREATE"
    case edit = "EDIT"
    case open = "OPEN"
    case close = "CLOSE"
    case run = "RUN"
    case fix = "FIX"
    case automate = "AUTOMATE"
    case summarize = "SUMMARIZE"
    case compare = "COMPARE"
    case remind = "REMIND"
    case remember = "REMEMBER"
    case forget = "FORGET"
    case plan = "PLAN"
    case find = "FIND"
    case focus = "FOCUS"
    case companion = "COMPANION"
}

enum DexterIntentTargetReference: String, Equatable {
    case applicationName = "applicationName"
    case currentPointerTarget = "currentPointerTarget"
    case currentContext = "currentContext"
    case freeText = "freeText"
    case none = "none"
}

struct DexterIntentTarget: Equatable {
    let reference: DexterIntentTargetReference
    let value: String?

    static let currentPointerTarget = DexterIntentTarget(reference: .currentPointerTarget, value: "currentPointerTarget")
    static let currentContext = DexterIntentTarget(reference: .currentContext, value: "currentContext")
    static let none = DexterIntentTarget(reference: .none, value: nil)

    static func application(_ name: String) -> DexterIntentTarget {
        DexterIntentTarget(reference: .applicationName, value: name)
    }

    static func freeText(_ text: String) -> DexterIntentTarget {
        DexterIntentTarget(reference: .freeText, value: text)
    }
}

struct DexterStructuredIntent: Equatable {
    let kind: DexterIntentKind
    let target: DexterIntentTarget
    let confidence: Double
    let normalizedUserMessage: String
}

enum DexterIntentComplexity: String, Equatable {
    case simple = "SIMPLE"
    case complex = "COMPLEX"
}

struct DexterIntentPlanStep: Equatable {
    let order: Int
    let identifier: String
    let title: String
}

struct DexterIntentPlan: Equatable {
    let goal: String
    let steps: [DexterIntentPlanStep]
    let requiredTools: [String]
    let requiredPermissions: [String]
    let expectedStates: [String]
    let stopConditions: [String]
    let actionBudget: Int
    let toolBudget: Int
    let timeoutSeconds: TimeInterval
}

struct DexterIntentEngineResult: Equatable {
    let structuredIntent: DexterStructuredIntent
    let complexity: DexterIntentComplexity
    let plan: DexterIntentPlan?
    let requiresClarification: Bool
    let clarificationPrompt: String?
}
