//
//  DexterHubTeachingMomentReporter.swift
//
//  Maps existing Dexter teaching engine / session state to Hub presentation events.
//

import Foundation

@MainActor
enum DexterHubTeachingMomentReporter {
    private static weak var eventBridge: DexterHubEventBridge?

    static func register(eventBridge: DexterHubEventBridge) {
        self.eventBridge = eventBridge
    }

    static func reportTeachingEngaged(
        teachingEngineResult: DexterTeachingEngineResult,
        contextPacket: DexterContextPacket,
        activePointInvokeSession: DexterPointInvokeSession?
    ) {
        guard teachingEngineResult.isTeachingTurn else { return }

        let topicSubtitle = teachingTopicSubtitle(
            contextPacket: contextPacket,
            pointInvokeSession: activePointInvokeSession
        )

        eventBridge?.broadcastTeachingMoment(
            phase: "coaching",
            title: "let's learn this.",
            subtitle: topicSubtitle,
            teachingStyle: teachingEngineResult.teachingStyle.rawValue,
            stepIndex: teachingEngineResult.updatedSession?.currentStepIndex,
            stepSummary: nil,
            stepPreviews: nil
        )
    }

    static func reportBlockingTeachingMessage(
        _ message: String,
        session: DexterTeachingSession?
    ) {
        let normalized = message.lowercased()
        if normalized.contains("finish this step") || normalized.contains("let's finish") {
            let stepSummary = session.map {
                DexterHubTeachingStepSummaryParser.hubSafeStepLabel(from: $0.currentInstructionSummary)
            }
            eventBridge?.broadcastTeachingMoment(
                phase: "yourTurn",
                title: "your turn.",
                subtitle: stepSummary ?? "Try the step on your Mac.",
                teachingStyle: session?.teachingStyle.rawValue,
                stepIndex: session?.currentStepIndex,
                stepSummary: stepSummary,
                stepPreviews: nil
            )
            return
        }

        if normalized.contains("don't see a clear change") || normalized.contains("do not see a clear change") {
            eventBridge?.broadcastTeachingMoment(
                phase: "yourTurn",
                title: "let's break it down.",
                subtitle: "Try the step again on your Mac.",
                teachingStyle: session?.teachingStyle.rawValue,
                stepIndex: session?.currentStepIndex,
                stepSummary: session.map {
                    DexterHubTeachingStepSummaryParser.hubSafeStepLabel(from: $0.currentInstructionSummary)
                },
                stepPreviews: nil
            )
            return
        }

        if normalized.contains("step") && session != nil {
            eventBridge?.broadcastTeachingMoment(
                phase: "step",
                title: "here's what's happening.",
                subtitle: DexterHubTeachingStepSummaryParser.hubSafeStepLabel(from: message),
                teachingStyle: session?.teachingStyle.rawValue,
                stepIndex: session?.currentStepIndex,
                stepSummary: DexterHubTeachingStepSummaryParser.hubSafeStepLabel(from: message),
                stepPreviews: nil
            )
        }
    }

    static func reportLessonDelivery(
        responseText: String,
        teachingStyle: DexterTeachingStyle,
        session: DexterTeachingSession?
    ) {
        let stepPreviews = DexterHubTeachingStepSummaryParser.parseStepPreviews(from: responseText)
        let currentStepSummary: String?
        if let session {
            currentStepSummary = DexterHubTeachingStepSummaryParser.hubSafeStepLabel(
                from: session.currentInstructionSummary
            )
        } else if let firstPreview = stepPreviews.first {
            currentStepSummary = firstPreview.label
        } else {
            currentStepSummary = DexterHubTeachingStepSummaryParser.hubSafeStepLabel(
                from: String(responseText.prefix(160))
            )
        }

        eventBridge?.broadcastTeachingMoment(
            phase: session?.phase == .wait ? "yourTurn" : "explaining",
            title: session?.phase == .wait ? "your turn." : "here's what's happening.",
            subtitle: currentStepSummary,
            teachingStyle: teachingStyle.rawValue,
            stepIndex: session?.currentStepIndex ?? stepPreviews.first?.index,
            stepSummary: currentStepSummary,
            stepPreviews: stepPreviews
        )
    }

    static func reportTeachingSessionPhaseChanged(_ session: DexterTeachingSession?) {
        guard let session else {
            eventBridge?.broadcastTeachingCleared()
            return
        }

        switch session.phase {
        case .wait:
            let stepSummary = DexterHubTeachingStepSummaryParser.hubSafeStepLabel(from: session.currentInstructionSummary)
            eventBridge?.broadcastTeachingMoment(
                phase: "yourTurn",
                title: "your turn.",
                subtitle: stepSummary,
                teachingStyle: session.teachingStyle.rawValue,
                stepIndex: session.currentStepIndex,
                stepSummary: stepSummary,
                stepPreviews: nil
            )
        case .instruction, .step:
            let stepSummary = DexterHubTeachingStepSummaryParser.hubSafeStepLabel(from: session.currentInstructionSummary)
            eventBridge?.broadcastTeachingMoment(
                phase: "step",
                title: "here's what's happening.",
                subtitle: stepSummary,
                teachingStyle: session.teachingStyle.rawValue,
                stepIndex: session.currentStepIndex,
                stepSummary: stepSummary,
                stepPreviews: nil
            )
        case .observe, .verify, .nextStep:
            eventBridge?.broadcastTeachingMoment(
                phase: "affirmation",
                title: "that's it.",
                subtitle: "Nice — ready for the next bit.",
                teachingStyle: session.teachingStyle.rawValue,
                stepIndex: session.currentStepIndex,
                stepSummary: nil,
                stepPreviews: nil
            )
        }
    }

    private static func teachingTopicSubtitle(
        contextPacket: DexterContextPacket,
        pointInvokeSession: DexterPointInvokeSession?
    ) -> String? {
        if let pointLabel = pointInvokeSession?.userFacingSemanticTargetLabel {
            return pointLabel
        }
        let fingerprint = DexterTeachingContextFingerprint.from(contextPacket: contextPacket)
        if let pointerTargetLabel = fingerprint.pointerTargetLabel, !pointerTargetLabel.isEmpty {
            return pointerTargetLabel
        }
        if let windowTitle = fingerprint.activeWindowTitle?.nonEmptyTrimmedValue {
            return windowTitle
        }
        if let applicationName = fingerprint.activeApplicationName?.nonEmptyTrimmedValue {
            return applicationName
        }
        return nil
    }
}
