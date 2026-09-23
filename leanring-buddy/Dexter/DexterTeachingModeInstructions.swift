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
                build understanding over time; keep the first spoken turn concise but complete enough to act on.
                end your response with exactly one machine-readable fix line on its own line: [DEXTER_FIX:corrected code or line here]
                the fix line must contain only the text that should replace the erroneous code (no markdown fences).
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

    private static func teachingBlock(
        modeName: String,
        hasScreenContext: Bool,
        emphasis: String
    ) -> String {
        let pointingInstruction: String
        if hasScreenContext {
            pointingInstruction = "when a specific on-screen control or area would help the user follow along, append a [POINT:x,y:label] tag after your spoken text (same rules as your pointing instructions)."
        } else {
            pointingInstruction = "do not reference on-screen elements you cannot see — no screenshot was provided for this turn."
        }

        return """
        dexter response mode: \(modeName)
        \(emphasis)
        structure your spoken response to cover what fits this question:
        - what is happening (or what they are looking at)
        - why it happens or why it matters
        - what the user should understand
        - what the next step is
        \(pointingInstruction)
        """
    }
}

enum DexterTeachingModeContextAdjuster {
    static func adjust(
        plan: DexterContextRelevancePlan,
        responseMode: DexterResponseMode,
        context: DexterContext
    ) -> DexterContextRelevancePlan {
        var adjustedPlan = plan

        let hasScreenCaptures = context.screen.captureAvailability == .available && !context.screen.allScreens.isEmpty
        let hasSelectedText = {
            guard let selectedText = context.selectedText.selectedText else { return false }
            return !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }()

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

        if context.currentTask.currentTaskDescription != nil {
            adjustedPlan.includeCurrentTask = responseMode != .answer
        }

        return adjustedPlan
    }
}
