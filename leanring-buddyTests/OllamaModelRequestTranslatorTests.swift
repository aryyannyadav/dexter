//
//  OllamaModelRequestTranslatorTests.swift
//

import Testing
@testable import Dexter

struct OllamaModelRequestTranslatorTests {
    @Test func extractsUserQuestionFromStructuredPrompt() {
        let structuredPrompt = """
        USER REQUEST

        what's on my screen?

        ACTIVE APPLICATION

        Xcode
        """
        let question = OllamaModelRequestTranslator.extractUserQuestion(from: structuredPrompt)
        #expect(question == "what's on my screen?")
    }

    @Test func visionMessagesExcludeConversationHistory() {
        let request = DexterModelGenerationRequest(
            systemPrompt: "Long system prompt",
            userPrompt: "USER REQUEST\n\nWhat am I looking at?",
            images: [DexterModelImageInput(imageData: Data([0xFF, 0xD8]), label: "screen")],
            conversationHistory: [
                DexterConversationExchange(userTranscript: "hello", assistantResponse: "hi")
            ]
        )

        let messages = OllamaModelRequestTranslator.chatMessages(for: request)
        #expect(messages.count == 1)
        #expect(messages.first?.role == .user)
        #expect(messages.first?.base64Images.isEmpty == false)
    }
}
