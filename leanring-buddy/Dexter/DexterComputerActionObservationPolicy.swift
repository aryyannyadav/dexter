//
//  DexterComputerActionObservationPolicy.swift
//  leanring-buddy
//

import Foundation

/// When computer actions must locate or interact with in-app UI, Dexter needs fresh observation (not minimal/skip context).
enum DexterComputerActionObservationPolicy {
    static func userMessageRequiresComputerUIObservation(
        normalizedUserMessage: String,
        userMessage: String
    ) -> Bool {
        if DexterActionRecoveryIntentRecognizer.recognizeRetry(fromUserMessage: userMessage) {
            return true
        }

        if let lifecyclePlan = DexterApplicationLifecycleIntentParser.parsePlan(from: normalizedUserMessage),
           lifecyclePlan.inApplicationDestinationLabel != nil {
            return true
        }

        let lifecycleApplicationName = DexterApplicationLifecycleIntentParser.parse(from: normalizedUserMessage)?.applicationName
        let followUpActions = DexterCompoundUserActionPlanParser.followUpActions(
            normalizedUserMessage: normalizedUserMessage,
            context: DexterContext(userMessage: DexterUserMessageContext(text: userMessage)),
            launchedApplicationName: lifecycleApplicationName,
            inApplicationDestinationLabel: nil
        )
        if followUpActions.contains(where: actionRequiresComputerUIObservation) {
            return true
        }

        let navigationSignals = [
            " go to ",
            " navigate to ",
            " and open ",
            " settings",
            " preferences"
        ]
        if normalizedUserMessage.hasPrefix("open ")
            || normalizedUserMessage.hasPrefix("launch ")
            || normalizedUserMessage.hasPrefix("focus ") {
            return navigationSignals.contains { normalizedUserMessage.contains($0) }
        }

        return false
    }

    static func actionRequiresComputerUIObservation(_ action: DexterAction) -> Bool {
        DexterUserInterfaceDestinationActionPreparer.isSemanticUserInterfaceDestinationAction(action)
    }
}
