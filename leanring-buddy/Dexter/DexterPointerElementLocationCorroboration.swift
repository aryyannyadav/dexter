//
//  DexterPointerElementLocationCorroboration.swift
//  leanring-buddy
//
//  Bridges `ElementLocationDetector` (full-screenshot vision) with pointer semantics:
//  when a detected element lies near the user's pointer, corroborate the semantic target.
//

import CoreGraphics
import Foundation

enum DexterPointerElementLocationCorroboration {
    static let defaultToleranceInPoints: CGFloat = 56

    /// `detectedLocationInDisplayPoints` uses AppKit display-local coordinates (bottom-left origin).
    static func corroboratesPointer(
        detectedLocationInDisplayPoints: CGPoint,
        pointerLocationInScreenSpace: CGPoint,
        displayFrameInScreenSpace: CGRect,
        toleranceInPoints: CGFloat = defaultToleranceInPoints
    ) -> Bool {
        let detectedInScreenSpace = CGPoint(
            x: displayFrameInScreenSpace.origin.x + detectedLocationInDisplayPoints.x,
            y: displayFrameInScreenSpace.origin.y + detectedLocationInDisplayPoints.y
        )
        let deltaX = detectedInScreenSpace.x - pointerLocationInScreenSpace.x
        let deltaY = detectedInScreenSpace.y - pointerLocationInScreenSpace.y
        let distanceSquared = deltaX * deltaX + deltaY * deltaY
        return distanceSquared <= toleranceInPoints * toleranceInPoints
    }

    static func visionEvidenceContribution(isCorroborated: Bool) -> DexterPointerEvidenceContribution? {
        guard isCorroborated else { return nil }
        return DexterPointerEvidenceContribution(
            source: .vision,
            detail: "ElementLocationDetector agrees with pointer position",
            weight: 0.12
        )
    }
}
