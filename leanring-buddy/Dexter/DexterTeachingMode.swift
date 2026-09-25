//
//  DexterTeachingMode.swift
//  leanring-buddy
//
//  First-class teaching modes (use ContextPacket; no automatic screen memory).
//

import Foundation

enum DexterTeachingMode: String, Codable, Equatable, CaseIterable {
    case explainElement = "EXPLAIN_ELEMENT"
    case explainScreen = "EXPLAIN_SCREEN"
    case explainApplication = "EXPLAIN_APPLICATION"
    case stepByStep = "STEP_BY_STEP"
    case interactiveTutorial = "INTERACTIVE_TUTORIAL"
}

/// Audience / depth style (combines with any teaching mode).
enum DexterTeachingStyle: String, Codable, Equatable {
    case standard = "STANDARD"
    case beginner = "BEGINNER"
    case expert = "EXPERT"
    case eli5 = "ELI5"
}

enum DexterTeachingStepPhase: String, Codable, Equatable, CaseIterable {
    case step = "STEP"
    case instruction = "INSTRUCTION"
    case wait = "WAIT"
    case observe = "OBSERVE"
    case verify = "VERIFY"
    case nextStep = "NEXT_STEP"
}

struct DexterTeachingContextFingerprint: Equatable, Codable {
    let activeApplicationName: String?
    let activeWindowTitle: String?
    let pointerTargetLabel: String?

    static func from(contextPacket: DexterContextPacket) -> DexterTeachingContextFingerprint {
        DexterTeachingContextFingerprint(
            activeApplicationName: contextPacket.activeApplication?.localizedName,
            activeWindowTitle: contextPacket.activeWindow?.title,
            pointerTargetLabel: contextPacket.pointerTarget?.semanticTarget.primaryLabel
                ?? contextPacket.pointer?.semanticTarget?.primaryLabel
        )
    }

    func differsMeaningfully(from other: DexterTeachingContextFingerprint) -> Bool {
        if let pointerTargetLabel, let otherLabel = other.pointerTargetLabel, pointerTargetLabel != otherLabel {
            return true
        }
        if let activeWindowTitle, let otherTitle = other.activeWindowTitle, activeWindowTitle != otherTitle {
            return true
        }
        if let activeApplicationName, let otherApp = other.activeApplicationName, activeApplicationName != otherApp {
            return true
        }
        return false
    }
}

struct DexterTeachingSession: Equatable, Codable {
    let lessonIdentifier: String
    let teachingMode: DexterTeachingMode
    var teachingStyle: DexterTeachingStyle
    var currentStepIndex: Int
    var phase: DexterTeachingStepPhase
    var currentInstructionSummary: String
    var fingerprintAtStepStart: DexterTeachingContextFingerprint
    var updatedAt: Date

    init(
        lessonIdentifier: String,
        teachingMode: DexterTeachingMode,
        teachingStyle: DexterTeachingStyle,
        currentStepIndex: Int = 1,
        phase: DexterTeachingStepPhase = .instruction,
        currentInstructionSummary: String,
        fingerprintAtStepStart: DexterTeachingContextFingerprint,
        updatedAt: Date = Date()
    ) {
        self.lessonIdentifier = lessonIdentifier
        self.teachingMode = teachingMode
        self.teachingStyle = teachingStyle
        self.currentStepIndex = currentStepIndex
        self.phase = phase
        self.currentInstructionSummary = currentInstructionSummary
        self.fingerprintAtStepStart = fingerprintAtStepStart
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case lessonIdentifier
        case teachingMode
        case teachingStyle
        case currentStepIndex
        case phase
        case currentInstructionSummary
        case fingerprintAtStepStart
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lessonIdentifier = try container.decode(String.self, forKey: .lessonIdentifier)
        teachingMode = try container.decode(DexterTeachingMode.self, forKey: .teachingMode)
        teachingStyle = try container.decode(DexterTeachingStyle.self, forKey: .teachingStyle)
        currentStepIndex = try container.decode(Int.self, forKey: .currentStepIndex)
        phase = try container.decode(DexterTeachingStepPhase.self, forKey: .phase)
        currentInstructionSummary = try container.decode(String.self, forKey: .currentInstructionSummary)
        fingerprintAtStepStart = try container.decode(DexterTeachingContextFingerprint.self, forKey: .fingerprintAtStepStart)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lessonIdentifier, forKey: .lessonIdentifier)
        try container.encode(teachingMode, forKey: .teachingMode)
        try container.encode(teachingStyle, forKey: .teachingStyle)
        try container.encode(currentStepIndex, forKey: .currentStepIndex)
        try container.encode(phase, forKey: .phase)
        try container.encode(currentInstructionSummary, forKey: .currentInstructionSummary)
        try container.encode(fingerprintAtStepStart, forKey: .fingerprintAtStepStart)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

struct DexterTeachingEngineResult: Equatable {
    let isTeachingTurn: Bool
    let teachingMode: DexterTeachingMode
    let teachingStyle: DexterTeachingStyle
    let mapsToResponseMode: DexterResponseMode
    /// When set, orchestrator returns this without calling the model.
    let blockingUserMessage: String?
    let updatedSession: DexterTeachingSession?
}
