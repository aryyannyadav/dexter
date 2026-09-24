//
//  DexterVisionProviderTests.swift
//  leanring-buddyTests
//

import CoreGraphics
import Foundation
import Testing
@testable import leanring_buddy

final class StubVisionProvider: VisionProvider {
    let providerName: String
    var isAvailableResult = true
    var responseToReturn: DexterVisionResponse
    var lastRequest: DexterVisionRequest?

    init(providerName: String, responseToReturn: DexterVisionResponse) {
        self.providerName = providerName
        self.responseToReturn = responseToReturn
    }

    func isAvailable() async -> Bool {
        isAvailableResult
    }

    func analyze(
        request: DexterVisionRequest,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> DexterVisionResponse {
        lastRequest = request
        await onTextChunk(responseToReturn.conversationalAnswer)
        return responseToReturn
    }
}

struct DexterVisionProviderTests {
    @Test func scopeSelectorPrefersPointerCropForWhatIsThis() {
        let context = DexterContext(
            userMessage: DexterUserMessageContext(text: "What is this?"),
            screen: DexterScreenContext(
                primaryScreenshot: sampleSnapshot(),
                allScreens: [sampleSnapshot()],
                captureAvailability: .available
            ),
            attention: sampleAttentionWithPointerInScreenshot()
        )

        let scope = DexterVisionScopeSelector.preferredScope(
            userMessage: "What is this?",
            dexterContext: context
        )
        #expect(scope == .pointerCrop)
    }

    @Test func scopeSelectorUsesFullScreenForScreenSummary() {
        let context = DexterContext(userMessage: DexterUserMessageContext(text: "what is on my screen"))
        let scope = DexterVisionScopeSelector.preferredScope(
            userMessage: "what is on my screen",
            dexterContext: context
        )
        #expect(scope == .fullScreen)
    }

    @Test func observationParserSplitsJsonObservations() {
        let raw = """
        That looks like a Save button.

        {"observations":[{"target":"Save","text":"Save","uiElement":"button","location":"toolbar","confidence":0.82,"state":"enabled"}]}
        """
        let parsed = DexterVisionObservationParser.parse(
            rawAssistantText: raw,
            scopeUsed: .pointerCrop,
            providerName: "Test"
        )
        #expect(parsed.conversationalAnswer.contains("Save button"))
        #expect(parsed.observations.count == 1)
        #expect(parsed.observations.first?.target == "Save")
        #expect(parsed.observations.first?.confidence == 0.82)
    }

    @Test func fallbackVisionProviderUsesPrimaryWhenAvailable() async throws {
        let primary = StubVisionProvider(
            providerName: "Primary",
            responseToReturn: DexterVisionResponse(
                conversationalAnswer: "primary answer",
                observations: [],
                scopeUsed: .fullScreen,
                providerName: "Primary"
            )
        )
        let fallback = StubVisionProvider(
            providerName: "Fallback",
            responseToReturn: DexterVisionResponse(
                conversationalAnswer: "fallback answer",
                observations: [],
                scopeUsed: .fullScreen,
                providerName: "Fallback"
            )
        )

        let provider = FallbackVisionProvider(primaryProvider: primary, fallbackProvider: fallback)
        let response = try await provider.analyze(
            request: sampleVisionRequest(),
            onTextChunk: { _ in }
        )
        #expect(response.conversationalAnswer == "primary answer")
    }

    @Test func fallbackVisionProviderUsesFallbackWhenPrimaryUnavailable() async throws {
        let primary = StubVisionProvider(
            providerName: "Primary",
            responseToReturn: DexterVisionResponse(
                conversationalAnswer: "primary answer",
                observations: [],
                scopeUsed: .fullScreen,
                providerName: "Primary"
            )
        )
        primary.isAvailableResult = false

        let fallback = StubVisionProvider(
            providerName: "Fallback",
            responseToReturn: DexterVisionResponse(
                conversationalAnswer: "fallback answer",
                observations: [],
                scopeUsed: .fullScreen,
                providerName: "Fallback"
            )
        )

        let provider = FallbackVisionProvider(primaryProvider: primary, fallbackProvider: fallback)
        let response = try await provider.analyze(
            request: sampleVisionRequest(),
            onTextChunk: { _ in }
        )
        #expect(response.conversationalAnswer == "fallback answer")
    }

    @Test func cloudVisionProviderIsNotAvailable() async {
        let cloud = CloudVisionProvider()
        #expect(await cloud.isAvailable() == false)
    }

    private static func sampleVisionRequest() -> DexterVisionRequest {
        DexterVisionRequest(
            userQuestion: "What is this?",
            scope: .pointerCrop,
            jpegImageData: Data([0xFF, 0xD8, 0xFF]),
            imageLabel: "test",
            pointerContextSummary: nil,
            wantsStructuredObservations: true
        )
    }

    private static func sampleSnapshot() -> DexterScreenCaptureSnapshot {
        DexterScreenCaptureSnapshot(
            imageData: Data(),
            label: "primary",
            isCursorScreen: true,
            displayWidthInPoints: 1440,
            displayHeightInPoints: 900,
            displayFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            screenshotWidthInPixels: 1280,
            screenshotHeightInPixels: 800
        )
    }

    private static func sampleAttentionWithPointerInScreenshot() -> DexterAttentionContext {
        DexterPointerAttentionCalculator.buildAttentionContext(
            pointerLocationInScreenSpace: CGPoint(x: 720, y: 450),
            display: DexterDisplayContext(
                displayIdentifier: 1,
                displayFrameInScreenSpace: CGRect(x: 0, y: 0, width: 1440, height: 900)
            ),
            primaryScreenshot: sampleSnapshot(),
            accessibilityHintAtPointer: DexterAccessibilityHintAtPointer(
                roleDescription: nil,
                title: nil,
                valueDescription: nil,
                availability: .notApplicable
            )
        )
    }
}
