//
//  DexterStructuredModelRequestBuilder.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

struct DexterStructuredModelRequest: Equatable {
    let userPrompt: String
    let images: [DexterModelImageInput]
    let conversationHistory: [DexterConversationExchange]
    let relevancePlan: DexterContextRelevancePlan
}

enum DexterStructuredModelRequestBuilder {
    static func build(
        dexterContext: DexterContext,
        relevancePlan: DexterContextRelevancePlan
    ) -> DexterStructuredModelRequest {
        var sections: [String] = []

        sections.append(sectionHeader("USER REQUEST"))
        sections.append(dexterContext.userMessage.text)

        if relevancePlan.includeActiveApplication {
            sections.append(sectionHeader("ACTIVE APPLICATION"))
            sections.append(activeApplicationDescription(from: dexterContext.activeApplication))
        }

        if relevancePlan.includeActiveWindow {
            sections.append(sectionHeader("ACTIVE WINDOW"))
            sections.append(activeWindowDescription(from: dexterContext.activeWindow))
        }

        if relevancePlan.includePointerContext {
            sections.append(sectionHeader("POINTER CONTEXT"))
            sections.append(pointerContextDescription(from: dexterContext.attention))
        }

        if relevancePlan.includeScreenContext {
            sections.append(sectionHeader("SCREEN CONTEXT"))
            sections.append(screenContextDescription(from: dexterContext.screen))
        }

        if relevancePlan.includeSelectedText {
            sections.append(sectionHeader("SELECTED TEXT"))
            sections.append(selectedTextDescription(from: dexterContext.selectedText))
        }

        if relevancePlan.includeRecentConversationInPrompt {
            sections.append(sectionHeader("RECENT CONVERSATION"))
            sections.append(recentConversationDescription(from: dexterContext.conversation.recentExchanges))
        }

        if relevancePlan.includeCurrentTask {
            sections.append(sectionHeader("CURRENT TASK"))
            sections.append(activeTaskDescription(from: dexterContext.currentTask))
        }

        if relevancePlan.includePersistentMemory {
            sections.append(sectionHeader("DEXTER MEMORY"))
            sections.append(persistentMemoryDescription(from: dexterContext.persistentMemory))
        }

        let structuredUserPrompt = sections.joined(separator: "\n\n")

        let images: [DexterModelImageInput]
        if relevancePlan.includeScreenContext,
           let primaryScreenshot = dexterContext.screen.primaryScreenshot ?? dexterContext.screenCaptures.first {
            images = [imageInput(for: primaryScreenshot, attention: dexterContext.attention)]
        } else {
            images = []
        }

        let conversationHistory: [DexterConversationExchange]
        if relevancePlan.includeRecentConversationInAPIHistory {
            conversationHistory = dexterContext.conversation.recentExchanges
        } else {
            conversationHistory = []
        }

        return DexterStructuredModelRequest(
            userPrompt: structuredUserPrompt,
            images: images,
            conversationHistory: conversationHistory,
            relevancePlan: relevancePlan
        )
    }

    private static func sectionHeader(_ title: String) -> String {
        title
    }

    private static func activeApplicationDescription(from application: DexterActiveApplicationContext) -> String {
        switch application.availability {
        case .available:
            if let localizedName = application.localizedName, let bundleIdentifier = application.bundleIdentifier {
                return "\(localizedName) (\(bundleIdentifier))"
            }
            return application.localizedName ?? application.bundleIdentifier ?? "unknown application"
        case .permissionMissing:
            return "unavailable (accessibility permission missing)"
        case .notApplicable:
            return "not collected"
        case .unavailable(let errorDescription):
            return "unavailable (\(errorDescription))"
        }
    }

    private static func activeTaskDescription(from taskContext: DexterTaskContext) -> String {
        var lines: [String] = []
        if let currentTaskDescription = taskContext.currentTaskDescription {
            lines.append(currentTaskDescription)
        }
        if let activeWorkflowTask = taskContext.activeWorkflowTask {
            lines.append("Workflow: \(activeWorkflowTask.title) (\(activeWorkflowTask.progressLabel))")
            lines.append("Workflow state: \(activeWorkflowTask.state.rawValue)")
            if let currentStep = activeWorkflowTask.currentStep {
                lines.append("Current step: \(currentStep.title) — \(currentStep.instruction)")
            }
        }
        if lines.isEmpty {
            return "none"
        }
        return lines.joined(separator: "\n")
    }

    private static func persistentMemoryDescription(from persistentMemory: DexterPersistentMemoryContext) -> String {
        var lines: [String] = []

        if !persistentMemory.userPreferences.isEmpty {
            lines.append("User preferences:")
            for preference in persistentMemory.userPreferences {
                lines.append("- \(preference.title): \(preference.content)")
            }
        }

        if !persistentMemory.rememberedFacts.isEmpty {
            lines.append("Remembered facts:")
            for fact in persistentMemory.rememberedFacts {
                lines.append("- \(fact.content)")
            }
        }

        if let workflowContext = persistentMemory.workflowContext {
            lines.append("Workflow context: \(workflowContext.summary)")
        }

        if lines.isEmpty {
            return "none"
        }

        return lines.joined(separator: "\n")
    }

    private static func activeWindowDescription(from window: DexterActiveWindowContext) -> String {
        switch window.availability {
        case .available:
            return window.title ?? "untitled window"
        case .permissionMissing:
            return "unavailable (accessibility permission missing)"
        case .notApplicable:
            return "not collected"
        case .unavailable(let errorDescription):
            return "unavailable (\(errorDescription))"
        }
    }

    private static func pointerContextDescription(from attention: DexterAttentionContext) -> String {
        var lines: [String] = []
        lines.append(String(
            format: "pointer at screen coordinates (%.0f, %.0f)",
            attention.pointerLocationInScreenSpace.x,
            attention.pointerLocationInScreenSpace.y
        ))

        if let displayIdentifier = attention.primaryDisplayIdentifier {
            lines.append("display identifier: \(displayIdentifier)")
        }

        if let pointerRelativeToDisplay = attention.pointerLocationRelativeToDisplay {
            lines.append(String(
                format: "pointer relative to display (%.0f, %.0f)",
                pointerRelativeToDisplay.x,
                pointerRelativeToDisplay.y
            ))
        }

        if let region = attention.regionAroundPointerInScreenSpace {
            lines.append(String(
                format: "attention region on screen: x=%.0f y=%.0f w=%.0f h=%.0f",
                region.origin.x,
                region.origin.y,
                region.width,
                region.height
            ))
        }

        if let pointerInScreenshot = attention.pointerLocationInPrimaryScreenshotPixels {
            lines.append(String(
                format: "pointer in primary screenshot pixels (%.0f, %.0f) on %dx%d image",
                pointerInScreenshot.xInPixels,
                pointerInScreenshot.yInPixels,
                pointerInScreenshot.screenshotWidthInPixels,
                pointerInScreenshot.screenshotHeightInPixels
            ))
        }

        let accessibilityHint = attention.accessibilityHintAtPointer
        if accessibilityHint.availability == .available {
            var hintParts: [String] = []
            if let roleDescription = accessibilityHint.roleDescription {
                hintParts.append("role hint: \(roleDescription)")
            }
            if let title = accessibilityHint.title {
                hintParts.append("title hint: \(title)")
            }
            if let valueDescription = accessibilityHint.valueDescription {
                hintParts.append("value hint: \(valueDescription)")
            }
            if !hintParts.isEmpty {
                lines.append("accessibility hints near pointer (unverified): \(hintParts.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func screenContextDescription(from screen: DexterScreenContext) -> String {
        switch screen.captureAvailability {
        case .available:
            let screenCount = screen.allScreens.count
            let primaryLabel = screen.primaryScreenshot?.label ?? "primary screen unavailable"
            return "captured \(screenCount) screen image(s). primary focus: \(primaryLabel)"
        case .permissionMissing:
            return "screenshot not captured (screen recording permission missing)"
        case .notApplicable:
            return "screenshot not requested for this turn"
        case .unavailable(let errorDescription):
            return "screenshot capture failed (\(errorDescription))"
        }
    }

    private static func selectedTextDescription(from selectedText: DexterSelectedTextContext) -> String {
        switch selectedText.availability {
        case .available:
            return selectedText.selectedText ?? "none"
        case .permissionMissing:
            return "unavailable (accessibility permission missing)"
        case .notApplicable:
            return "none"
        case .unavailable(let errorDescription):
            return "unavailable (\(errorDescription))"
        }
    }

    private static func recentConversationDescription(from exchanges: [DexterConversationExchange]) -> String {
        guard !exchanges.isEmpty else { return "no prior exchanges in this session" }

        return exchanges.map { exchange in
            "user: \(exchange.userTranscript)\nassistant: \(exchange.assistantResponse)"
        }.joined(separator: "\n\n")
    }

    private static func imageInput(
        for capture: DexterScreenCaptureSnapshot,
        attention: DexterAttentionContext
    ) -> DexterModelImageInput {
        let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
        var label = capture.label + dimensionInfo

        if capture.isCursorScreen,
           let pointerPixels = attention.pointerLocationInPrimaryScreenshotPixels {
            label += " (pointer at \(Int(pointerPixels.xInPixels)), \(Int(pointerPixels.yInPixels)) in screenshot pixel space)"
            if let region = attention.regionAroundPointerInPrimaryScreenshotPixels,
               region.rectInPixels.width > 0, region.rectInPixels.height > 0 {
                label += " (attention region around pointer: \(Int(region.rectInPixels.width))x\(Int(region.rectInPixels.height)) px)"
            }
        }

        return DexterModelImageInput(imageData: capture.imageData, label: label)
    }
}
