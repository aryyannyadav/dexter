//
//  DexterVisionObservationParser.swift
//  leanring-buddy
//

import Foundation

private struct DexterVisionObservationsEnvelope: Decodable {
    let observations: [DexterVisionVisualObservation]
}

enum DexterVisionObservationParser {
    static func parse(
        rawAssistantText: String,
        scopeUsed: DexterVisionImageScope,
        providerName: String
    ) -> DexterVisionResponse {
        let sanitized = OllamaResponseSanitizer.userFacingAssistantText(
            content: rawAssistantText,
            separateThinkingField: nil
        )

        if let (answer, observations) = splitAnswerAndObservations(from: sanitized) {
            return DexterVisionResponse(
                conversationalAnswer: answer,
                observations: observations,
                scopeUsed: scopeUsed,
                providerName: providerName
            )
        }

        return DexterVisionResponse(
            conversationalAnswer: sanitized,
            observations: [],
            scopeUsed: scopeUsed,
            providerName: providerName
        )
    }

    private static func splitAnswerAndObservations(
        from sanitizedText: String
    ) -> (String, [DexterVisionVisualObservation])? {
        guard let jsonLineRange = sanitizedText.range(of: "{\"observations\"", options: .backwards) else {
            return nil
        }

        let answerPart = String(sanitizedText[..<jsonLineRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonPart = String(sanitizedText[jsonLineRange.lowerBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonPart.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(DexterVisionObservationsEnvelope.self, from: jsonData)
        else {
            return nil
        }

        let conversationalAnswer = answerPart.isEmpty ? sanitizedText : answerPart
        return (conversationalAnswer, envelope.observations)
    }
}
