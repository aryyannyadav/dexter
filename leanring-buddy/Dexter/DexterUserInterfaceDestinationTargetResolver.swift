//
//  DexterUserInterfaceDestinationTargetResolver.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterUserInterfaceDestinationResolutionSource: String {
    case accessibility = "accessibility"
    case openClawAccessibility = "openclaw_accessibility"
    case ocr = "ocr"
    case vision = "vision"
}

struct DexterUserInterfaceDestinationResolvedTarget: Equatable {
    let centerInScreenSpace: CGPoint?
    let elementRef: String?
    let resolutionSource: DexterUserInterfaceDestinationResolutionSource
    let observationId: String
}

struct DexterUserInterfaceDestinationTargetResolutionInput: Equatable {
    let destinationLabel: String
    let parentApplicationName: String?
    let dexterContext: DexterContext
    let observationId: String
    let hasAccessibilityPermission: Bool
}

enum DexterUserInterfaceDestinationTargetResolver {
    @MainActor
    static func resolve(
        input: DexterUserInterfaceDestinationTargetResolutionInput,
        visionProvider: VisionProvider?
    ) async -> DexterUserInterfaceDestinationResolvedTarget? {
        let destinationLabel = input.destinationLabel
        let parentApplicationName = input.parentApplicationName
        let observationId = input.observationId

        DexterObservabilityLog.target(
            "application=\(parentApplicationName ?? "frontmost") target=\(destinationLabel) observationId=\(observationId)"
        )

        let screenshot = DexterUserInterfaceDestinationScreenshotSelector.bestScreenshot(for: input.dexterContext)
        let screenshotAvailable = screenshot != nil
            && input.dexterContext.screen.captureAvailability == .available
        DexterObservabilityLog.target("screenshotAvailable=\(screenshotAvailable)")

        let accessibilityAvailable = input.hasAccessibilityPermission
        DexterObservabilityLog.target("accessibilityAvailable=\(accessibilityAvailable)")

        if accessibilityAvailable {
            if let center = DexterAccessibilityDestinationLocator.locateCenterInScreenSpace(
                destinationLabel: destinationLabel,
                expectedApplicationName: parentApplicationName,
                hasAccessibilityPermission: true
            ) {
                logResolved(source: .accessibility, observationId: observationId)
                return DexterUserInterfaceDestinationResolvedTarget(
                    centerInScreenSpace: center,
                    elementRef: destinationLabel,
                    resolutionSource: .accessibility,
                    observationId: observationId
                )
            }
        }

        if let openClawTarget = await OpenClawAccessibilityDestinationLocator.resolve(
            destinationLabel: destinationLabel,
            parentApplicationName: parentApplicationName
        ) {
            if let center = openClawTarget.centerInScreenSpace {
                logResolved(source: .openClawAccessibility, observationId: observationId)
                return DexterUserInterfaceDestinationResolvedTarget(
                    centerInScreenSpace: center,
                    elementRef: openClawTarget.elementRef ?? destinationLabel,
                    resolutionSource: .openClawAccessibility,
                    observationId: observationId
                )
            }
            if let elementRef = openClawTarget.elementRef?.nonEmptyTrimmedValue {
                logResolved(source: .openClawAccessibility, observationId: observationId, targetType: "element")
                return DexterUserInterfaceDestinationResolvedTarget(
                    centerInScreenSpace: nil,
                    elementRef: elementRef,
                    resolutionSource: .openClawAccessibility,
                    observationId: observationId
                )
            }
        }

        var ocrAvailable = false
        if let screenshot {
            ocrAvailable = true
            DexterObservabilityLog.target("ocrAvailable=true")
            if let center = DexterScreenOCRDestinationLocator.locateCenterInScreenSpace(
                destinationLabel: destinationLabel,
                screenshot: screenshot
            ) {
                logResolved(source: .ocr, observationId: observationId)
                return DexterUserInterfaceDestinationResolvedTarget(
                    centerInScreenSpace: center,
                    elementRef: destinationLabel,
                    resolutionSource: .ocr,
                    observationId: observationId
                )
            }
        } else {
            DexterObservabilityLog.target("ocrAvailable=false")
        }

        var visionAvailable = false
        if let screenshot, let visionProvider {
            visionAvailable = await visionProvider.isAvailable()
            DexterObservabilityLog.target("visionAvailable=\(visionAvailable)")
            if visionAvailable {
                if let center = await resolveWithVision(
                    destinationLabel: destinationLabel,
                    parentApplicationName: parentApplicationName,
                    observationId: observationId,
                    screenshot: screenshot,
                    visionProvider: visionProvider
                ) {
                    logResolved(source: .vision, observationId: observationId)
                    return DexterUserInterfaceDestinationResolvedTarget(
                        centerInScreenSpace: center,
                        elementRef: destinationLabel,
                        resolutionSource: .vision,
                        observationId: observationId
                    )
                }
            }
        } else {
            DexterObservabilityLog.target("visionAvailable=false")
        }

        DexterObservabilityLog.target(
            "application=\(parentApplicationName ?? "frontmost") target=\(destinationLabel) resolved=false observationId=\(observationId)"
        )
        DexterObservabilityLog.target("resolutionSource=unresolved")
        return nil
    }

    @MainActor
    private static func resolveWithVision(
        destinationLabel: String,
        parentApplicationName: String?,
        observationId: String,
        screenshot: DexterScreenCaptureSnapshot,
        visionProvider: VisionProvider
    ) async -> CGPoint? {
        let userQuestion = DexterVisionUITargetLocalization.userQuestion(
            destinationLabel: destinationLabel,
            applicationName: parentApplicationName,
            observationId: observationId
        )

        let visionRequest = DexterVisionRequest(
            userQuestion: userQuestion,
            scope: .fullScreen,
            jpegImageData: screenshot.imageData,
            imageLabel: screenshot.label,
            pointerContextSummary: nil,
            wantsStructuredObservations: false,
            systemPromptSupplement: DexterVisionUITargetLocalization.systemPromptSupplement
        )

        do {
            DexterObservabilityLog.target("visionRequest observationId=\(observationId)")
            let response = try await visionProvider.analyze(request: visionRequest, onTextChunk: { _ in })
            let localization = DexterVisionUITargetLocalization.parse(rawText: response.conversationalAnswer)
            guard localization.found else { return nil }
            return DexterVisionUITargetLocalization.centerInScreenSpace(
                localization: localization,
                screenshot: screenshot
            )
        } catch {
            DexterObservabilityLog.target("visionFailed observationId=\(observationId)")
            return nil
        }
    }

    private static func logResolved(
        source: DexterUserInterfaceDestinationResolutionSource,
        observationId: String,
        targetType: String = "coordinate"
    ) {
        DexterObservabilityLog.target("resolutionSource=\(source.rawValue)")
        DexterObservabilityLog.target("resolved=true targetType=\(targetType) observationId=\(observationId)")
    }
}

enum DexterUserInterfaceDestinationScreenshotSelector {
    static func bestScreenshot(for context: DexterContext) -> DexterScreenCaptureSnapshot? {
        if let primaryScreenshot = context.screen.primaryScreenshot {
            return primaryScreenshot
        }
        if let displayFrame = context.display?.displayFrameInScreenSpace {
            if let matching = context.screen.allScreens.first(where: { snapshot in
                snapshot.displayFrame == displayFrame
            }) {
                return matching
            }
        }
        if let cursorScreen = context.screen.allScreens.first(where: { $0.isCursorScreen }) {
            return cursorScreen
        }
        return context.screen.allScreens.first
    }
}
