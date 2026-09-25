//
//  DexterTeachingOverlayStore.swift
//  leanring-buddy
//

import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class DexterTeachingOverlayStore: ObservableObject {
    @Published private(set) var activeSession: DexterTeachingOverlaySession?

    private var expirationTask: Task<Void, Never>?

    func dismiss(reason: String = "dismissed") {
        expirationTask?.cancel()
        expirationTask = nil
        guard activeSession != nil else { return }
        activeSession = nil
        DexterObservabilityLog.voice("teaching overlay cleared (\(reason))")
    }

    func present(session: DexterTeachingOverlaySession) {
        expirationTask?.cancel()
        activeSession = session
        scheduleExpiration(at: session.expiresAt)
    }

    func presentPointAskCaptureMarker(session: DexterPointInvokeSession) {
        let pointerLocation = session.pointerLocationInScreenSpace
        guard let displayFrame = DexterPointAskHighlightPlanner.displayFrameContaining(
            pointInScreenSpace: pointerLocation
        ) else {
            dismiss(reason: "point_ask_no_display")
            return
        }

        let label = session.userFacingSemanticTargetLabel
        let annotations = DexterPointAskHighlightPlanner.planCaptureMarkerAnnotations(
            pointerLocationInScreenSpace: pointerLocation,
            displayFrameInScreenSpace: displayFrame,
            targetLabel: label
        )

        let overlaySession = DexterTeachingOverlaySession(
            displayFrameInScreenSpace: displayFrame,
            annotations: annotations,
            currentStepIndex: nil,
            lifetimeSeconds: 600
        )
        present(session: overlaySession)
    }

    func presentFromModelTurn(
        targetGlobalPoint: CGPoint?,
        targetDisplayFrame: CGRect?,
        elementLabel: String?,
        pointerGlobalPoint: CGPoint?,
        teachingSession: DexterTeachingSession?,
        shouldShowTeachingAnnotations: Bool
    ) {
        guard shouldShowTeachingAnnotations else {
            dismiss(reason: "turn_not_teaching")
            return
        }

        let referencePoint = targetGlobalPoint ?? pointerGlobalPoint
        guard let displayFrame = targetDisplayFrame ?? NSScreen.screens.first(where: { screen in
            guard let referencePoint else { return false }
            return screen.frame.contains(referencePoint)
        })?.frame else {
            dismiss(reason: "no_display_frame")
            return
        }

        let annotations = DexterTeachingAnnotationPlanner.planAnnotations(
            input: DexterTeachingAnnotationPlanner.PlanningInput(
                displayFrameInScreenSpace: displayFrame,
                targetGlobalPoint: targetGlobalPoint,
                targetLabel: elementLabel,
                pointerGlobalPoint: pointerGlobalPoint,
                teachingSession: teachingSession,
                attentionRegionRadiusInPoints: DexterPointerAttentionCalculator.defaultRegionRadiusInPoints
            )
        )

        guard !annotations.isEmpty else {
            dismiss(reason: "no_grounded_annotations")
            return
        }

        let session = DexterTeachingOverlaySession(
            displayFrameInScreenSpace: displayFrame,
            annotations: annotations,
            currentStepIndex: teachingSession?.currentStepIndex
        )
        present(session: session)
    }

    private func scheduleExpiration(at date: Date) {
        let delay = max(0, date.timeIntervalSinceNow)
        expirationTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            dismiss(reason: "timeout")
        }
    }
}
