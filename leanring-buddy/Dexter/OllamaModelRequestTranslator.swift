//
//  OllamaModelRequestTranslator.swift
//  leanring-buddy
//

import Foundation

/// Builds Ollama-specific chat payloads. Vision turns use a minimal message list so screenshots are not drowned by Dexter context sections.
enum OllamaModelRequestTranslator {
    static func chatMessages(for request: DexterModelGenerationRequest) -> [AIChatMessage] {
        if request.images.isEmpty {
            return textOnlyMessages(for: request)
        }
        return minimalVisionMessages(for: request)
    }

    private static func textOnlyMessages(for request: DexterModelGenerationRequest) -> [AIChatMessage] {
        var chatMessages: [AIChatMessage] = [
            AIChatMessage(role: .system, content: request.systemPrompt)
        ]

        for exchange in request.conversationHistory {
            chatMessages.append(AIChatMessage(role: .user, content: exchange.userTranscript))
            chatMessages.append(AIChatMessage(role: .assistant, content: exchange.assistantResponse))
        }

        chatMessages.append(AIChatMessage(role: .user, content: request.userPrompt))
        return chatMessages
    }

    private static func minimalVisionMessages(for request: DexterModelGenerationRequest) -> [AIChatMessage] {
        let userQuestion = extractUserQuestion(from: request.userPrompt)

        return [
            AIChatMessage(role: .system, content: DexterVisionSystemPrompt.screenAnalysisSystemPrompt),
            AIChatMessage(
                role: .user,
                content: userQuestion,
                base64Images: encodeImagesForOllama(from: request.images)
            )
        ]
    }

    static func encodeImagesForOllama(from imageInputs: [DexterModelImageInput]) -> [String] {
        imageInputs.compactMap { imageInput in
            guard let compressedJPEG = DexterContextImageEncoder.jpegDataForVisionModel(
                from: imageInput.imageData,
                diagnosticReason: "visual-request"
            ) else {
                return imageInput.imageData.base64EncodedString()
            }
            return compressedJPEG.base64EncodedString()
        }
    }

    static func extractUserQuestion(from structuredUserPrompt: String) -> String {
        let userRequestHeader = "USER REQUEST"
        let normalizedPrompt = structuredUserPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let headerRange = normalizedPrompt.range(of: userRequestHeader) else {
            return String(normalizedPrompt.prefix(1_500))
        }

        var afterHeader = normalizedPrompt[headerRange.upperBound...]
        if afterHeader.hasPrefix("\n\n") {
            afterHeader = afterHeader.dropFirst(2)
        } else if afterHeader.hasPrefix("\n") {
            afterHeader = afterHeader.dropFirst(1)
        }

        let sectionHeaders = [
            "\n\nACTIVE APPLICATION",
            "\n\nACTIVE WINDOW",
            "\n\nPOINTER CONTEXT",
            "\n\nSCREEN CONTEXT",
            "\n\nSELECTED TEXT",
            "\n\nRECENT CONVERSATION",
            "\n\nCURRENT TASK",
            "\n\nDEXTER MEMORY"
        ]

        var questionText = String(afterHeader)
        for sectionHeader in sectionHeaders {
            if let sectionRange = questionText.range(of: sectionHeader) {
                questionText = String(questionText[..<sectionRange.lowerBound])
            }
        }

        let trimmedQuestion = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuestion.isEmpty {
            return "What am I looking at on my screen?"
        }
        return String(trimmedQuestion.prefix(1_500))
    }
}
