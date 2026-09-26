import Testing
@testable import leanring_buddy

@Suite("DexterPointInvokeSession Hub presentation")
struct DexterPointInvokeSessionHubPresentationTests {
    @Test("hub subtitle combines resolved target and application")
    func hubSubtitleCombinesTargetAndApplication() {
        let session = makeSession(
            applicationName: "Safari",
            windowTitle: "Example",
            semanticTarget: makeTarget(label: "Settings", confidence: 0.72, source: .accessibility)
        )
        #expect(session.hubTargetPresentationSubtitle == "Settings · Safari")
        #expect(session.requiresHubTargetConfirmationBeat == false)
        #expect(session.primaryResolutionSourceForDiagnostics == "accessibility")
    }

    @Test("low confidence triggers uncertain prompt label")
    func lowConfidenceTriggersUncertainPrompt() {
        let session = makeSession(
            applicationName: "Telegram",
            windowTitle: nil,
            semanticTarget: makeTarget(label: "Send", confidence: 0.31, source: .ocr)
        )
        #expect(session.requiresHubTargetConfirmationBeat == true)
        #expect(session.hubUncertainTargetPromptLabel == "Send")
        #expect(session.primaryResolutionSourceForDiagnostics == "ocr")
    }

    @Test("missing semantic target has no uncertain label")
    func missingSemanticTargetHasNoUncertainLabel() {
        let session = makeSession(applicationName: "Preview", windowTitle: "Diagram.pdf", semanticTarget: nil)
        #expect(session.requiresHubTargetConfirmationBeat == true)
        #expect(session.hubUncertainTargetPromptLabel == nil)
        #expect(session.hubTargetPresentationSubtitle == "Preview — Diagram.pdf")
        #expect(session.primaryResolutionSourceForDiagnostics == "none")
    }

    private func makeSession(
        applicationName: String,
        windowTitle: String?,
        semanticTarget: DexterPointerSemanticTarget?
    ) -> DexterPointInvokeSession {
        let contextSnapshot = DexterContextSnapshot(
            capturedAt: Date(),
            permissionState: DexterContextPermissionState(
                hasScreenRecordingPermission: true,
                hasAccessibilityPermission: true,
                hasScreenContentPermission: true
            ),
            primaryScreenshotJPEG: nil,
            screenshotLabel: nil,
            activeApplicationName: applicationName,
            activeWindowTitle: windowTitle,
            pointerLocationInScreenSpace: .zero,
            selectedText: nil,
            browserURL: nil,
            browserPageTitle: nil,
            screenCaptureAvailability: .available,
            userRequestedScreenContext: true
        )
        return DexterPointInvokeSession(
            pointerLocationInScreenSpace: .zero,
            capturedAt: Date(),
            contextSnapshot: contextSnapshot,
            screenCaptureSnapshots: [],
            pointerSemanticTarget: semanticTarget
        )
    }

    private func makeTarget(
        label: String,
        confidence: Double,
        source: DexterPointerEvidenceSource
    ) -> DexterPointerSemanticTarget {
        DexterPointerSemanticTarget(
            primaryLabel: label,
            roleDescription: "button",
            valueDescription: nil,
            applicationContextLabel: nil,
            windowContextLabel: nil,
            ocrTextNearPointer: nil,
            visionAppearanceHint: nil,
            evidence: [
                DexterPointerEvidenceContribution(source: source, detail: label, weight: 0.9)
            ],
            confidence: confidence
        )
    }
}
