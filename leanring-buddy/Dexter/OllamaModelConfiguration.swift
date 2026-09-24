//
//  OllamaModelConfiguration.swift
//  leanring-buddy
//

import Foundation

/// Single source of truth for local Ollama model names used by Dexter.
enum OllamaModelConfiguration {
    static let textModelName = "qwen3.5:9b"
    static let visionModelName = "qwen3.5:4b"
}
