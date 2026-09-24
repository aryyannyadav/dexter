//
//  DexterTeachingModeInstructions.swift
//  leanring-buddy
//

import Foundation

enum DexterTeachingModeInstructions {
    static func supplementalSystemInstructions(
        for responseMode: DexterResponseMode,
        hasScreenContext: Bool
    ) -> String {
        supplementalSystemInstructions(
            for: responseMode,
            teachingMode: nil,
            teachingStyle: .standard,
            hasScreenContext: hasScreenContext,
            teachingSession: nil,
            contextPacketSummary: nil
        )
    }

    static func supplementalSystemInstructions(
        for responseMode: DexterResponseMode,
        teachingMode: DexterTeachingMode?,
        teachingStyle: DexterTeachingStyle,
        hasScreenContext: Bool,
        teachingSession: DexterTeachingSession?,
        contextPacketSummary: String?
    ) -> String {
        let baseModeInstructions: String
        if let teachingMode {
            baseModeInstructions = teachingModeBlock(
                teachingMode: teachingMode,
                teachingStyle: teachingStyle,
                hasScreenContext: hasScreenContext,
                teachingSession: teachingSession,
                contextPacketSummary: contextPacketSummary
            )
        } else {
            baseModeInstructions = legacyResponseModeBlock(
                for: responseMode,
                hasScreenContext: hasScreenContext
            )
        }

        guard !baseModeInstructions.isEmpty else { return "" }
        return baseModeInstructions
    }

    private static func teachingModeBlock(
        teachingMode: DexterTeachingMode,
        teachingStyle: DexterTeachingStyle,
        hasScreenContext: Bool,
        teachingSession: DexterTeachingSession?,
        contextPacketSummary: String?
    ) -> String {
        var lines: [String] = []
        lines.append("dexter teaching mode: \(teachingMode.rawValue)")
        lines.append(styleLine(for: teachingStyle))

        switch teachingMode {
        case .explainElement:
            lines.append("explain the UI element under the user's pointer using ContextPacket pointer target metadata first, then visible screenshot evidence. do not claim you clicked anything.")
        case .explainScreen:
            lines.append("explain what matters on the current screen in 2–5 conversational sentences. no full UI inventory.")
        case .explainApplication:
            lines.append("explain the frontmost application and window context. tie guidance to what the user is doing now.")
        case .stepByStep:
            lines.append("give exactly one actionable step for the current lesson step, then stop. wait for the user to complete it before continuing.")
        case .interactiveTutorial:
            lines.append("run a short interactive lesson: one concept, one action, check understanding. pause after each step.")
        }

        if let teachingSession {
            lines.append("lesson step \(teachingSession.currentStepIndex), phase \(teachingSession.phase.rawValue).")
            if teachingSession.phase == .wait {
                lines.append("the user should complete the current step before you advance. do not skip ahead.")
            }
        }

        if let contextPacketSummary, !contextPacketSummary.isEmpty {
            lines.append("context packet summary:\n\(contextPacketSummary)")
        }

        lines.append(pointingLine(hasScreenContext: hasScreenContext))
        lines.append("""
        teaching rules: answer from visible information and packet metadata only; be concise; no fabricated controls; no reasoning dump; if uncertain, say so.
        """)
        return lines.joined(separator: "\n")
    }

    private static func styleLine(for teachingStyle: DexterTeachingStyle) -> String {
        switch teachingStyle {
        case .standard:
            return "audience style: STANDARD (clear, neutral depth)."
        case .beginner:
            return "audience style: BEGINNER (define terms, short sentences, reassuring tone)."
        case .expert:
            return "audience style: EXPERT (precise terminology, skip basics)."
        case .eli5:
            return "audience style: ELI5 (simple analogies, no jargon)."
        }
    }

    private static func legacyResponseModeBlock(
        for responseMode: DexterResponseMode,
        hasScreenContext: Bool
    ) -> String {
        switch responseMode {
        case .answer:
            return ""
        case .act:
            return """
            dexter response mode: ACT
            the user is asking you to perform or drive an action. you cannot execute actions yet — describe clearly what should happen, what the user should verify afterward, and the safest next step. do not claim you already clicked or changed anything.
            """
        case .troubleshoot:
            return teachingBlock(
                modeName: "TROUBLESHOOT",
                hasScreenContext: hasScreenContext,
                emphasis: "focus on the error or failure the user is seeing. use screen context and selected text when provided."
            )
        case .teach:
            return teachingBlock(
                modeName: "TEACH",
                hasScreenContext: hasScreenContext,
                emphasis: """
                give a structured explanation that fits on one screen of chat. use these sections in order (short headings or clear paragraphs):
                1. What it is
                2. Why it happened (or why it matters)
                3. What the user should understand
                4. A simple example (only if helpful)
                5. What to do next (user actions only — do not claim you will click or change anything)
                stay concise; no chain-of-thought; no markdown code fences unless a tiny example is essential.
                """
            )
        case .guide:
            return teachingBlock(
                modeName: "GUIDE",
                hasScreenContext: hasScreenContext,
                emphasis: "give a clear sequence the user can follow; one step at a time in speech, with the immediate next step last."
            )
        case .explain:
            return teachingBlock(
                modeName: "EXPLAIN",
                hasScreenContext: hasScreenContext,
                emphasis: """
                prioritize clarity and causality — what and why — over a long procedure.
                when the user points at a control (pointer + screenshot context), describe what it is, what it does today, and what would likely change if they enabled or toggled it — without claiming you already changed anything.
                """
            )
        }
    }

    private static func pointingLine(hasScreenContext: Bool) -> String {
        if hasScreenContext {
            return "when a specific on-screen control or area would help the user follow along, append a [POINT:x,y:label] tag after your spoken text (same rules as your pointing instructions)."
        }
        return "do not reference on-screen elements you cannot see — no screenshot was provided for this turn."
    }

    private static func teachingBlock(
        modeName: String,
        hasScreenContext: Bool,
        emphasis: String
    ) -> String {
        """
        dexter response mode: \(modeName)
        \(emphasis)
        structure your spoken response to cover what fits this question:
        - what is happening (or what they are looking at)
        - why it happens or why it matters
        - what the user should understand
        - what the next step is
        \(pointingLine(hasScreenContext: hasScreenContext))
        """
    }
}

enum DexterTeachingModeContextAdjuster {
    static func adjust(
        plan: DexterContextRelevancePlan,
        responseMode: DexterResponseMode,
        context: DexterContext
    ) -> DexterContextRelevancePlan {
        adjust(
            plan: plan,
            responseMode: responseMode,
            teachingMode: nil,
            context: context
        )
    }

    static func adjust(
        plan: DexterContextRelevancePlan,
        responseMode: DexterResponseMode,
        teachingMode: DexterTeachingMode?,
        context: DexterContext
    ) -> DexterContextRelevancePlan {
        var adjustedPlan = plan

        let hasScreenCaptures = context.screen.captureAvailability == .available && !context.screen.allScreens.isEmpty
        let hasSelectedText = {
            guard let selectedText = context.selectedText.selectedText else { return false }
            return !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()

        if let teachingMode {
            switch teachingMode {
            case .explainElement:
                adjustedPlan.includePointerContext = true
                adjustedPlan.includeActiveWindow = true
                adjustedPlan.includeScreenContext = hasScreenCaptures
            case .explainScreen:
                adjustedPlan.includeScreenContext = hasScreenCaptures
                adjustedPlan.includePointerContext = hasScreenCaptures
                adjustedPlan.includeActiveWindow = true
            case .explainApplication:
                adjustedPlan.includeActiveApplication = true
                adjustedPlan.includeActiveWindow = true
                adjustedPlan.includeScreenContext = hasScreenCaptures
            case .stepByStep, .interactiveTutorial:
                adjustedPlan.includeActiveApplication = true
                adjustedPlan.includeActiveWindow = true
                adjustedPlan.includePointerContext = true
                adjustedPlan.includeScreenContext = hasScreenCaptures
                adjustedPlan.includeSelectedText = hasSelectedText
            }
        } else {
            switch responseMode {
            case .answer:
                break
            case .act:
                if hasScreenCaptures {
                    adjustedPlan.includeScreenContext = true
                    adjustedPlan.includePointerContext = true
                    adjustedPlan.includeActiveApplication = true
                    adjustedPlan.includeActiveWindow = true
                }
            case .troubleshoot:
                adjustedPlan.includeActiveApplication = true
                adjustedPlan.includeActiveWindow = true
                if hasScreenCaptures {
                    adjustedPlan.includeScreenContext = true
                    adjustedPlan.includePointerContext = true
                }
                if hasSelectedText {
                    adjustedPlan.includeSelectedText = true
                }
            case .teach, .explain, .guide:
                if hasScreenCaptures {
                    adjustedPlan.includeScreenContext = true
                    adjustedPlan.includePointerContext = true
                    adjustedPlan.includeActiveWindow = true
                    adjustedPlan.includeActiveApplication = responseMode == .teach || responseMode == .guide
                }
                if hasSelectedText && responseMode == .teach {
                    adjustedPlan.includeSelectedText = true
                }
            }
        }

        if context.currentTask.currentTaskDescription != nil {
            adjustedPlan.includeCurrentTask = responseMode != .answer
        }

        return adjustedPlan
    }
}
