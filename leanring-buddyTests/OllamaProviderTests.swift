//
//  OllamaProviderTests.swift
//  leanring-buddyTests
//

import Testing
@testable import Dexter

struct OllamaProviderTests {
    @Test func modelNameMatchingAcceptsExactAndVariantTags() {
        let installed = ["qwen3.5:9b", "llama3.2:latest"]
        #expect(OllamaProvider.modelNameIsAvailable("qwen3.5:9b", in: installed))
        #expect(!OllamaProvider.modelNameIsAvailable("qwen3.5:27b", in: installed))
    }

    @Test func decodesNonStreamingChatResponse() throws {
        let json = """
        {
          "model": "qwen3.5:9b",
          "message": {
            "role": "assistant",
            "content": "Hello! How can I help you today?"
          },
          "done": true
        }
        """
        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: Data(json.utf8))
        #expect(decoded.message?.content == "Hello! How can I help you today?")
    }
}
