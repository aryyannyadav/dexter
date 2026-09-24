//
//  DexterModelBackendKind.swift
//  leanring-buddy
//

import Foundation

enum DexterModelBackendKind: String, Equatable, CaseIterable {
    case ollama = "OLLAMA"
    case claude = "CLAUDE"
    case openAI = "OPENAI"
}
