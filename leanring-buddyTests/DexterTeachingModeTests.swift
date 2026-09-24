//
//  DexterTeachingModeTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

@MainActor
struct DexterTeachingModeTests {
    @Test func whatIsThisMapsToExplainElement() {
        let packet = samplePacket(withPointerTarget: "Submit button")
        let intent = DexterStructuredIntent(
            kind: .explain,
            target: .currentPointerTarget,
            confidence: 0.9,
            normalizedUserMessage: "what is this"
        )

        let mode = DexterTeachingEngine.resolveTeachingMode(
            normalizedMessage: "what is this",
            structuredIntent: intent,
            contextPacket: packet
        )
        #expect(mode == .explainElement)
    }

    @Test func explainScreenUtteranceMapsToExplainScreen() {
        let mode = DexterTeachingEngine.resolveTeachingMode(
            normalizedMessage: "explain this screen",
            structuredIntent: DexterStructuredIntent(
                kind: .explain,
                target: .currentContext,
                confidence: 0.8,
                normalizedUserMessage: "explain this screen"
            ),
            contextPacket: samplePacket(withPointerTarget: nil)
        )
        #expect(mode == .explainScreen)
    }

    @Test func teachMeThisMapsToInteractiveTutorial() {
        let mode = DexterTeachingEngine.resolveTeachingMode(
            normalizedMessage: "teach me this",
            structuredIntent: DexterStructuredIntent(
                kind: .teach,
                target: .currentContext,
                confidence: 0.9,
                normalizedUserMessage: "teach me this"
            ),
            contextPacket: samplePacket(withPointerTarget: "Toggle")
        )
        #expect(mode == .interactiveTutorial)
    }

    @Test func howDoIUseMapsToStepByStep() {
        let mode = DexterTeachingEngine.resolveTeachingMode(
            normalizedMessage: "how do i use this",
            structuredIntent: DexterStructuredIntent(
                kind: .guide,
                target: .currentPointerTarget,
                confidence: 0.85,
                normalizedUserMessage: "how do i use this"
            ),
            contextPacket: samplePacket(withPointerTarget: "Enable notifications")
        )
        #expect(mode == .stepByStep)
    }

    @Test func eli5StyleDetected() {
        let style = DexterTeachingEngine.resolveTeachingStyle(normalizedMessage: "explain this eli5")
        #expect(style == .eli5)
    }

    @Test func stepSessionBlocksWhenUserSkipsAheadDuringWait() async {
        let sessionStore = DexterTeachingSessionStore()
        let fingerprint = DexterTeachingContextFingerprint(
            activeApplicationName: "Safari",
            activeWindowTitle: "Apple",
            pointerTargetLabel: "Learn more"
        )
        sessionStore.replaceSession(
            DexterTeachingSession(
                lessonIdentifier: "STEP-1",
                teachingMode: .stepByStep,
                teachingStyle: .standard,
                currentStepIndex: 1,
                phase: .wait,
                currentInstructionSummary: "Click the Learn more link.",
                fingerprintAtStepStart: fingerprint
            )
        )

        let packet = samplePacket(withPointerTarget: "Learn more")
        let result = DexterTeachingEngine.evaluate(
            userMessage: "What is this button?",
            contextPacket: packet,
            structuredIntent: DexterStructuredIntent(
                kind: .explain,
                target: .currentPointerTarget,
                confidence: 0.9,
                normalizedUserMessage: "what is this button"
            ),
            sessionStore: sessionStore
        )

        #expect(result.blockingUserMessage != nil)
        #expect(result.blockingUserMessage?.contains("finish this step") == true)
    }

    @Test func contextPacketSummaryDoesNotIncludeRawScreenBytes() {
        let packet = samplePacket(withPointerTarget: "Save")
        let summary = DexterTeachingPacketPromptBuilder.contextSummary(from: packet)
        #expect(summary.contains("pointer target"))
        #expect(!summary.contains("imageData"))
    }

    @Test func nonTeachingTurnDoesNotActivateTeachingEngine() async {
        let sessionStore = DexterTeachingSessionStore()
        let result = DexterTeachingEngine.evaluate(
            userMessage: "hello",
            contextPacket: samplePacket(withPointerTarget: nil),
            structuredIntent: DexterStructuredIntent(
                kind: .companion,
                target: .none,
                confidence: 0.9,
                normalizedUserMessage: "hello"
            ),
            sessionStore: sessionStore
        )
        #expect(!result.isTeachingTurn)
    }

    private static func samplePacket(withPointerTarget: String?) -> DexterContextPacket {
        let semanticTarget: DexterPointerSemanticTarget?
        if let withPointerTarget = withPointerTarget {
            semanticTarget = DexterPointerSemanticTarget(
                primaryLabel: withPointerTarget,
                roleDescription: "button",
                valueDescription: nil,
                applicationContextLabel: nil,
                windowContextLabel: nil,
                ocrTextNearPointer: nil,
                visionAppearanceHint: nil,
                evidence: [],
                confidence: 0.8
            )
        } else {
            semanticTarget = nil
        }

        return DexterContextPacket(
            userIntent: DexterUserIntentContext(userMessage: "test", minimumRelevanceLevel: .object),
            activeApplication: DexterActiveApplicationContext(
                bundleIdentifier: "com.apple.Safari",
                localizedName: "Safari",
                availability: .available
            ),
            activeWindow: DexterActiveWindowContext(title: "Apple", availability: .available),
            display: nil,
            pointer: nil,
            pointerTarget: semanticTarget.map { target in
                DexterPointerTargetContext(
                    semanticTarget: target,
                    accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                        roleDescription: "button",
                        title: withPointerTarget,
                        valueDescription: nil,
                        availability: .available
                    ),
                    attentionRegionInScreenSpace: nil
                )
            },
            screenContext: DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .available
            ),
            selectedText: nil,
            clipboard: nil,
            memory: nil,
            conversation: nil,
            currentTask: nil,
            recentActions: nil,
            availableTools: nil,
            permissions: nil,
            projectContext: nil,
            browserContext: nil,
            attention: nil
        )
    }
}
