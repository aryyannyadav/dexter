//
//  DexterPointAskHighlightPlanner.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

enum DexterPointAskHighlightPlanner {
    static func planCaptureMarkerAnnotations(
        pointerLocationInScreenSpace: CGPoint,
        displayFrameInScreenSpace: CGRect,
        targetLabel: String?
    ) -> [DexterAnnotation] {
        let overlayPoint = DexterOverlayScreenCoordinateMapper.overlayPoint(
            appKitGlobalPoint: pointerLocationInScreenSpace,
            displayFrameInScreenSpace: displayFrameInScreenSpace
        )

        var annotations: [DexterAnnotation] = [
            DexterAnnotation(
                kind: .targetRing,
                center: overlayPoint,
                size: CGSize(width: 48, height: 48),
                targetOpacity: 0.55
            ),
            DexterAnnotation(
                kind: .circle,
                center: overlayPoint,
                size: CGSize(width: 28, height: 28),
                targetOpacity: 0.42
            )
        ]

        if let targetLabel, !targetLabel.isEmpty {
            annotations.append(
                DexterAnnotation(
                    kind: .textLabel,
                    center: CGPoint(x: overlayPoint.x + 10, y: overlayPoint.y - 44),
                    text: targetLabel,
                    targetOpacity: 0.95
                )
            )
        }

        return annotations
    }

    static func displayFrameContaining(pointInScreenSpace: CGPoint) -> CGRect? {
        NSScreen.screens.first { screen in
            screen.frame.contains(pointInScreenSpace)
        }?.frame
    }
}
