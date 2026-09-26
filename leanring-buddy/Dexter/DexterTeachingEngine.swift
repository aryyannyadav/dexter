//
//  DexterTeachingEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterTeachingEngine {
    static func evaluate(
        userMessage: String,
        contextPacket: DexterContextPacket,
        structuredIntent: DexterStructuredIntent,
        sessionStore: DexterTeachingSessionStore
    ) -> DexterTeachingEngineResult {
        let normalizedMessage = normalize(userMessage)
        let responseMode = DexterIntentResponseModeMapper.responseMode(for: structuredIntent)

        guard shouldActivateTeaching(
            normalizedMessage: normalizedMessage,
            structuredIntent: structuredIntent,
            responseMode: responseMode,
            sessionStore: sessionStore
        ) else {
            return DexterTeachingEngineResult(
                isTeachingTurn: false,
                teachingMode: .explainElement,
                teachingStyle: .standard,
                mapsToResponseMode: responseMode,
                blockingUserMessage: nil,
                updatedSession: nil
            )
        }

        let teachingMode = resolveTeachingMode(
            normalizedMessage: normalizedMessage,
            structuredIntent: structuredIntent,
            contextPacket: contextPacket
        )
        let teachingStyle = resolveTeachingStyle(normalizedMessage: normalizedMessage)

        if teachingMode == .stepByStep || teachingMode == .interactiveTutorial {
            return evaluateStepBasedTurn(
                normalizedMessage: normalizedMessage,
                teachingMode: teachingMode,
                teachingStyle: teachingStyle,
                responseMode: responseMode,
                contextPacket: contextPacket,
                sessionStore: sessionStore
            )
        }

        sessionStore.replaceSession(nil)

        return DexterTeachingEngineResult(
            isTeachingTurn: true,
            teachingMode: teachingMode,
            teachingStyle: teachingStyle,
            mapsToResponseMode: responseMode,
            blockingUserMessage: nil,
            updatedSession: nil
        )
    }

    static func shouldActivateTeaching(
        normalizedMessage: String,
        structuredIntent: DexterStructuredIntent,
        responseMode: DexterResponseMode,
        sessionStore: DexterTeachingSessionStore
    ) -> Bool {
        if sessionStore.activeSession != nil {
            return true
        }

        switch responseMode {
        case .explain, .teach, .guide:
            return true
        case .troubleshoot:
            return true
        case .answer, .act:
            break
        }

        if DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedMessage) {
            return true
        }

        let explicitPhrases = [
            "how do i use this",
            "explain this screen",
            "teach me",
            "step by step",
            "walk me through"
        ]
        return explicitPhrases.contains { normalizedMessage.contains($0) }
    }

    private static func evaluateStepBasedTurn(
        normalizedMessage: String,
        teachingMode: DexterTeachingMode,
        teachingStyle: DexterTeachingStyle,
        responseMode: DexterResponseMode,
        contextPacket: DexterContextPacket,
        sessionStore: DexterTeachingSessionStore
    ) -> DexterTeachingEngineResult {
        let fingerprint = DexterTeachingContextFingerprint.from(contextPacket: contextPacket)

        if var session = sessionStore.activeSession,
           session.teachingMode == teachingMode {
            return advanceStepSession(
                session: session,
                normalizedMessage: normalizedMessage,
                fingerprint: fingerprint,
                teachingStyle: teachingStyle,
                responseMode: responseMode,
                sessionStore: sessionStore
            )
        }

        let lessonIdentifier = lessonIdentifier(for: contextPacket, mode: teachingMode)
        let newSession = DexterTeachingSession(
            lessonIdentifier: lessonIdentifier,
            teachingMode: teachingMode,
            teachingStyle: teachingStyle,
            currentStepIndex: 1,
            phase: .instruction,
            currentInstructionSummary: "Awaiting first instruction from Dexter.",
            fingerprintAtStepStart: fingerprint
        )
        sessionStore.replaceSession(newSession)

        return DexterTeachingEngineResult(
            isTeachingTurn: true,
            teachingMode: teachingMode,
            teachingStyle: teachingStyle,
            mapsToResponseMode: responseMode == .act ? .guide : responseMode,
            blockingUserMessage: nil,
            updatedSession: newSession
        )
    }

    private static func advanceStepSession(
        session: DexterTeachingSession,
        normalizedMessage: String,
        fingerprint: DexterTeachingContextFingerprint,
        teachingStyle: DexterTeachingStyle,
        responseMode: DexterResponseMode,
        sessionStore: DexterTeachingSessionStore
    ) -> DexterTeachingEngineResult {
        var updatedSession = session
        updatedSession.updatedAt = Date()
        updatedSession.teachingStyle = teachingStyle

        if session.phase == .wait {
            if matchesStepCompletionUtterance(normalizedMessage) {
                updatedSession.phase = .observe
                sessionStore.replaceSession(updatedSession)
                updatedSession.phase = .verify
                let verified = fingerprint.differsMeaningfully(from: session.fingerprintAtStepStart)
                    || matchesStrongCompletionUtterance(normalizedMessage)
                if verified {
                    updatedSession.phase = .nextStep
                    updatedSession.currentStepIndex += 1
                    updatedSession.phase = .instruction
                    updatedSession.fingerprintAtStepStart = fingerprint
                    updatedSession.currentInstructionSummary = "Step \(updatedSession.currentStepIndex) — continue the lesson."
                    sessionStore.replaceSession(updatedSession)
                    return DexterTeachingEngineResult(
                        isTeachingTurn: true,
                        teachingMode: session.teachingMode,
                        teachingStyle: teachingStyle,
                        mapsToResponseMode: .guide,
                        blockingUserMessage: nil,
                        updatedSession: updatedSession
                    )
                }
                sessionStore.replaceSession(updatedSession)
                return DexterTeachingEngineResult(
                    isTeachingTurn: true,
                    teachingMode: session.teachingMode,
                    teachingStyle: teachingStyle,
                    mapsToResponseMode: .guide,
                    blockingUserMessage: "I don't see a clear change yet. Finish the step I gave you, then say done when ready.",
                    updatedSession: updatedSession
                )
            }

            if matchesHelpUtterance(normalizedMessage) {
                sessionStore.replaceSession(updatedSession)
                return DexterTeachingEngineResult(
                    isTeachingTurn: true,
                    teachingMode: session.teachingMode,
                    teachingStyle: teachingStyle,
                    mapsToResponseMode: .guide,
                    blockingUserMessage: nil,
                    updatedSession: updatedSession
                )
            }

            sessionStore.replaceSession(updatedSession)
            return DexterTeachingEngineResult(
                isTeachingTurn: true,
                teachingMode: session.teachingMode,
                teachingStyle: teachingStyle,
                mapsToResponseMode: responseMode,
                blockingUserMessage: "Let's finish this step first: \(session.currentInstructionSummary) Say done when you've completed it.",
                updatedSession: updatedSession
            )
        }

        sessionStore.replaceSession(updatedSession)
        return DexterTeachingEngineResult(
            isTeachingTurn: true,
            teachingMode: session.teachingMode,
            teachingStyle: teachingStyle,
            mapsToResponseMode: responseMode == .act ? .guide : responseMode,
            blockingUserMessage: nil,
            updatedSession: updatedSession
        )
    }

    static func markInstructionDelivered(
        instructionSummary: String,
        sessionStore: DexterTeachingSessionStore
    ) {
        guard var session = sessionStore.activeSession else { return }
        session.currentInstructionSummary = instructionSummary
        session.phase = .wait
        session.updatedAt = Date()
        sessionStore.replaceSession(session)
    }

    static func resolveTeachingMode(
        normalizedMessage: String,
        structuredIntent: DexterStructuredIntent,
        contextPacket: DexterContextPacket
    ) -> DexterTeachingMode {
        if normalizedMessage.contains("how do i use this")
            || normalizedMessage.contains("how do i use that")
            || normalizedMessage.contains("step by step") {
            return .stepByStep
        }

        if matchesInteractiveTutorialIntent(normalizedMessage) {
            return .interactiveTutorial
        }

        if normalizedMessage.contains("explain this screen")
            || normalizedMessage.contains("explain the screen")
            || normalizedMessage.contains("explain my screen") {
            return .explainScreen
        }

        if normalizedMessage.contains("explain this app")
            || normalizedMessage.contains("explain the app")
            || normalizedMessage.contains("explain this application") {
            return .explainApplication
        }

        let hasPointerTarget = contextPacket.pointerTarget != nil
            || contextPacket.pointer?.semanticTarget != nil
        if DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedMessage)
            || structuredIntent.target.reference == .currentPointerTarget
            || (structuredIntent.kind == .explain && hasPointerTarget) {
            return .explainElement
        }

        if structuredIntent.kind == .teach {
            return .interactiveTutorial
        }

        if contextPacket.screenContext?.captureAvailability == .available {
            return .explainScreen
        }

        if contextPacket.activeApplication?.localizedName != nil {
            return .explainApplication
        }

        return .explainElement
    }

    static func resolveTeachingStyle(normalizedMessage: String) -> DexterTeachingStyle {
        if normalizedMessage.contains("eli5")
            || normalizedMessage.contains("like i'm 5")
            || normalizedMessage.contains("like im 5")
            || normalizedMessage.contains("explain like i'm five") {
            return .eli5
        }
        if normalizedMessage.contains("beginner") || normalizedMessage.contains("i'm new") || normalizedMessage.contains("im new")
            || normalizedMessage.contains("simple explanation") {
            return .beginner
        }
        if normalizedMessage.contains("expert") || normalizedMessage.contains("advanced") || normalizedMessage.contains("in depth")
            || normalizedMessage.contains("technical") {
            return .expert
        }
        if let hubPreferredStyle = DexterHubTeachingStylePreferenceStore.preferredTeachingStyle() {
            return hubPreferredStyle
        }
        return .standard
    }

    private static func matchesInteractiveTutorialIntent(_ normalizedMessage: String) -> Bool {
        let phrases = ["teach me this", "teach me that", "interactive lesson", "walk me through"]
        return phrases.contains { normalizedMessage.contains($0) }
            || normalizedMessage.hasPrefix("teach me ")
    }

    private static func matchesStepCompletionUtterance(_ normalizedMessage: String) -> Bool {
        let phrases = ["done", "finished", "i did it", "completed", "next step", "ready", "ok done", "all set"]
        return phrases.contains { normalizedMessage == $0 || normalizedMessage.hasPrefix($0 + " ") }
    }

    private static func matchesStrongCompletionUtterance(_ normalizedMessage: String) -> Bool {
        normalizedMessage.contains("done") || normalizedMessage.contains("finished")
    }

    private static func matchesHelpUtterance(_ normalizedMessage: String) -> Bool {
        let phrases = ["help", "stuck", "confused", "don't understand", "do not understand"]
        return phrases.contains { normalizedMessage.contains($0) }
    }

    private static func lessonIdentifier(for contextPacket: DexterContextPacket, mode: DexterTeachingMode) -> String {
        let fingerprint = DexterTeachingContextFingerprint.from(contextPacket: contextPacket)
        let anchor = fingerprint.pointerTargetLabel
            ?? fingerprint.activeWindowTitle
            ?? fingerprint.activeApplicationName
            ?? "general"
        return "\(mode.rawValue)-\(anchor.prefix(48))"
    }

    private static func normalize(_ userMessage: String) -> String {
        userMessage
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
