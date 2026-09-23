//
//  ContextProvider.swift
//  leanring-buddy
//

import Foundation

/// Legacy context surface. Prefer `DexterContextAssembler` for new code.
protocol ContextProvider: AnyObject {
    func buildContext(forUserTranscript userTranscript: String) async throws -> DexterContext
}

/// Thin adapter that delegates to `DexterContextAssembler`.
@MainActor
final class ScreenCaptureContextProvider: ContextProvider {
    private let contextAssembler: DexterContextAssembler

    init(contextAssembler: DexterContextAssembler) {
        self.contextAssembler = contextAssembler
    }

    func buildContext(forUserTranscript userTranscript: String) async throws -> DexterContext {
        let request = DexterContextAssemblyRequest(userMessage: userTranscript)
        return await contextAssembler.assembleContext(request: request)
    }
}
