//
//  VisionProvider.swift
//  leanring-buddy
//
//  Vision proposes information only — never executes actions.
//  Planner → policy → OpenClaw → verifier handle execution separately.
//

import Foundation

enum DexterVisionImageScope: String, Equatable {
    case fullScreen = "fullScreen"
    case pointerCrop = "pointerCrop"
    case relevantRegion = "relevantRegion"
}

struct DexterPreparedVisionPayload: Equatable {
    let jpegImageData: Data
    let scope: DexterVisionImageScope
    let imageLabel: String
    let pixelWidth: Int
    let pixelHeight: Int
}

struct DexterVisionVisualObservation: Equatable, Codable {
    let target: String?
    let text: String?
    let uiElement: String?
    let location: String?
    let confidence: Double?
    let state: String?
}

struct DexterVisionRequest: Equatable {
    let userQuestion: String
    let scope: DexterVisionImageScope
    let jpegImageData: Data
    let imageLabel: String
    let pointerContextSummary: String?
    let wantsStructuredObservations: Bool
    /// When set, appended to the default vision system prompt (e.g. UI target localization JSON).
    let systemPromptSupplement: String?

    init(
        userQuestion: String,
        scope: DexterVisionImageScope,
        jpegImageData: Data,
        imageLabel: String,
        pointerContextSummary: String? = nil,
        wantsStructuredObservations: Bool = false,
        systemPromptSupplement: String? = nil
    ) {
        self.userQuestion = userQuestion
        self.scope = scope
        self.jpegImageData = jpegImageData
        self.imageLabel = imageLabel
        self.pointerContextSummary = pointerContextSummary
        self.wantsStructuredObservations = wantsStructuredObservations
        self.systemPromptSupplement = systemPromptSupplement
    }
}

struct DexterVisionResponse: Equatable {
    let conversationalAnswer: String
    let observations: [DexterVisionVisualObservation]
    let scopeUsed: DexterVisionImageScope
    let providerName: String
}

enum VisionProviderError: LocalizedError, Equatable {
    case providerUnavailable(String)
    case imageEncodingFailed
    case invalidResponse
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let detail):
            return detail
        case .imageEncodingFailed:
            return "Couldn't prepare the screen for vision analysis."
        case .invalidResponse:
            return "Vision returned an empty or invalid response."
        case .notImplemented(let detail):
            return detail
        }
    }
}

/// Analyzes on-demand screen captures. Implementations must not trigger actions.
protocol VisionProvider: AnyObject {
    var providerName: String { get }
    func isAvailable() async -> Bool
    func analyze(
        request: DexterVisionRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterVisionResponse
}
