//
//  DexterVisionRequestPreparer.swift
//  leanring-buddy
//

import Foundation

enum DexterVisionRequestPreparer {
    static func preparePayload(
        dexterContext: DexterContext,
        userMessage: String
    ) -> DexterPreparedVisionPayload? {
        guard let primaryScreenshot = dexterContext.screen.primaryScreenshot
            ?? dexterContext.screenCaptures.first(where: { $0.isCursorScreen })
            ?? dexterContext.screenCaptures.first
        else {
            return nil
        }

        let scope = DexterVisionScopeSelector.preferredScope(
            userMessage: userMessage,
            dexterContext: dexterContext
        )

        guard let jpegData = DexterVisionImageEncoder.encodedJPEG(
            from: primaryScreenshot,
            scope: scope,
            attentionContext: dexterContext.attention
        ) else {
            return nil
        }

        let dimensions = DexterVisionImageEncoder.pixelDimensions(of: jpegData)
        let scopeLabel = scope.rawValue
        let imageLabel = "\(primaryScreenshot.label) (vision scope: \(scopeLabel))"

        return DexterPreparedVisionPayload(
            jpegImageData: jpegData,
            scope: scope,
            imageLabel: imageLabel,
            pixelWidth: dimensions?.width ?? primaryScreenshot.screenshotWidthInPixels,
            pixelHeight: dimensions?.height ?? primaryScreenshot.screenshotHeightInPixels
        )
    }

    static func buildVisionRequest(
        structuredUserPrompt: String,
        dexterContext: DexterContext,
        preparedPayload: DexterPreparedVisionPayload
    ) -> DexterVisionRequest {
        let userQuestion = OllamaModelRequestTranslator.extractUserQuestion(from: structuredUserPrompt)
        let pointerSummary = dexterContext.pointer?.semanticTarget?.modelSummaryLine

        let wantsStructuredObservations = dexterContext.pointer?.semanticTarget != nil
            || DexterContextRelevancePlanner.matchesWhatIsThisPublic(
                OllamaModelRequestTranslator.extractUserQuestion(from: structuredUserPrompt).lowercased()
            )

        return DexterVisionRequest(
            userQuestion: userQuestion,
            scope: preparedPayload.scope,
            jpegImageData: preparedPayload.jpegImageData,
            imageLabel: preparedPayload.imageLabel,
            pointerContextSummary: pointerSummary,
            wantsStructuredObservations: wantsStructuredObservations
        )
    }
}
