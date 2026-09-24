//
//  DexterVisionScopeSelector.swift
//  leanring-buddy
//

import Foundation

enum DexterVisionScopeSelector {
    static func preferredScope(userMessage: String, dexterContext: DexterContext) -> DexterVisionImageScope {
        let normalizedMessage = userMessage.lowercased()

        let prefersFullScreen = [
            "what's on my screen",
            "what is on my screen",
            "explain this window",
            "explain the window",
            "look at my screen",
            "see my screen",
            "entire screen",
            "full screen"
        ].contains { normalizedMessage.contains($0) }

        if prefersFullScreen {
            return .fullScreen
        }

        let prefersPointerCrop = DexterContextRelevancePlanner.matchesWhatIsThisPublic(normalizedMessage)
            || normalizedMessage.contains("this button")
            || normalizedMessage.contains("that button")
            || normalizedMessage.contains("under my cursor")
            || normalizedMessage.contains("under the cursor")
            || normalizedMessage.contains("pointing at")
            || normalizedMessage.contains("how do i use this")
            || normalizedMessage.contains("how do i use that")
            || normalizedMessage.contains("why is this red")
            || normalizedMessage.contains("why is that red")
            || DexterPointerControlWorkflow.matchesPointerActIntent(normalizedUserMessage: normalizedMessage
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "!", with: "")
                .replacingOccurrences(of: "?", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines))

        let hasPointerGeometry = dexterContext.attention.pointerLocationInPrimaryScreenshotPixels != nil

        if prefersPointerCrop && hasPointerGeometry {
            return .pointerCrop
        }

        if hasPointerGeometry {
            return .relevantRegion
        }

        return .fullScreen
    }
}
