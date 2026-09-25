//
//  DexterTeachingAnnotationPlanner.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterTeachingAnnotationPlanner {
    struct PlanningInput: Equatable {
        let displayFrameInScreenSpace: CGRect
        let targetGlobalPoint: CGPoint?
        let targetLabel: String?
        let pointerGlobalPoint: CGPoint?
        let teachingSession: DexterTeachingSession?
        let attentionRegionRadiusInPoints: CGFloat
    }

    static func planAnnotations(input: PlanningInput) -> [DexterAnnotation] {
        guard let targetGlobal = input.targetGlobalPoint else {
            return pointerOnlyAnnotations(input: input)
        }

        let targetOverlay = DexterOverlayScreenCoordinateMapper.overlayPoint(
            appKitGlobalPoint: targetGlobal,
            displayFrameInScreenSpace: input.displayFrameInScreenSpace
        )

        var annotations: [DexterAnnotation] = []

        if let stepIndex = input.teachingSession?.currentStepIndex {
            annotations.append(
                DexterAnnotation(
                    kind: .stepNumber,
                    center: CGPoint(x: targetOverlay.x - 36, y: targetOverlay.y - 36),
                    size: CGSize(width: 28, height: 28),
                    stepNumber: stepIndex
                )
            )
        }

        annotations.append(
            DexterAnnotation(
                kind: .targetRing,
                center: targetOverlay,
                size: CGSize(width: 56, height: 56)
            )
        )

        annotations.append(
            DexterAnnotation(
                kind: .circle,
                center: targetOverlay,
                size: CGSize(width: 44, height: 44)
            )
        )

        let arrowStart = CGPoint(
            x: targetOverlay.x - 72,
            y: targetOverlay.y - 56
        )
        annotations.append(
            DexterAnnotation(
                kind: .arrow,
                center: arrowStart,
                size: CGSize(
                    width: targetOverlay.x - arrowStart.x,
                    height: targetOverlay.y - arrowStart.y
                )
            )
        )

        if let label = input.targetLabel, !label.isEmpty {
            annotations.append(
                DexterAnnotation(
                    kind: .textLabel,
                    center: CGPoint(x: targetOverlay.x + 8, y: targetOverlay.y - 48),
                    text: label
                )
            )
        }

        let highlightSize = CGSize(width: 120, height: 72)
        annotations.append(
            DexterAnnotation(
                kind: .highlight,
                center: targetOverlay,
                size: highlightSize
            )
        )

        if let pointerGlobal = input.pointerGlobalPoint {
            let pointerOverlay = DexterOverlayScreenCoordinateMapper.overlayPoint(
                appKitGlobalPoint: pointerGlobal,
                displayFrameInScreenSpace: input.displayFrameInScreenSpace
            )
            let distance = hypot(pointerOverlay.x - targetOverlay.x, pointerOverlay.y - targetOverlay.y)
            if distance > 24 {
                annotations.append(
                    DexterAnnotation(
                        kind: .pointer,
                        center: pointerOverlay,
                        size: CGSize(width: 14, height: 14)
                    )
                )
            }
        }

        return annotations
    }

    private static func pointerOnlyAnnotations(input: PlanningInput) -> [DexterAnnotation] {
        guard let pointerGlobal = input.pointerGlobalPoint else { return [] }
        let pointerOverlay = DexterOverlayScreenCoordinateMapper.overlayPoint(
            appKitGlobalPoint: pointerGlobal,
            displayFrameInScreenSpace: input.displayFrameInScreenSpace
        )

        var annotations: [DexterAnnotation] = []
        let regionSize = input.attentionRegionRadiusInPoints * 2
        annotations.append(
            DexterAnnotation(
                kind: .highlight,
                center: pointerOverlay,
                size: CGSize(width: regionSize, height: regionSize * 0.65)
            )
        )
        annotations.append(
            DexterAnnotation(
                kind: .targetRing,
                center: pointerOverlay,
                size: CGSize(width: 48, height: 48)
            )
        )
        if let stepIndex = input.teachingSession?.currentStepIndex {
            annotations.append(
                DexterAnnotation(
                    kind: .stepNumber,
                    center: CGPoint(x: pointerOverlay.x - 32, y: pointerOverlay.y - 32),
                    stepNumber: stepIndex
                )
            )
        }
        return annotations
    }
}
