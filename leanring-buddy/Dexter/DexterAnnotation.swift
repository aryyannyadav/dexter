//
//  DexterAnnotation.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterAnnotationKind: String, Codable, Equatable, CaseIterable {
    case arrow
    case circle
    case rectangle
    case highlight
    case targetRing
    case pointer
    case textLabel
    case stepNumber
}

/// A single on-screen teaching mark in overlay-local coordinates (top-left origin within one display).
struct DexterAnnotation: Identifiable, Equatable {
    let id: UUID
    let kind: DexterAnnotationKind
    /// Center or anchor in overlay space.
    let center: CGPoint
    /// Optional size for rects, rings, highlights.
    var size: CGSize
    var text: String?
    var stepNumber: Int?
    /// 0...1 animated opacity (store sets target; view animates).
    var targetOpacity: Double

    init(
        id: UUID = UUID(),
        kind: DexterAnnotationKind,
        center: CGPoint,
        size: CGSize = .zero,
        text: String? = nil,
        stepNumber: Int? = nil,
        targetOpacity: Double = 1
    ) {
        self.id = id
        self.kind = kind
        self.center = center
        self.size = size
        self.text = text
        self.stepNumber = stepNumber
        self.targetOpacity = targetOpacity
    }
}

struct DexterTeachingOverlaySession: Equatable, Identifiable {
    let id: UUID
    let displayFrameInScreenSpace: CGRect
    var annotations: [DexterAnnotation]
    var currentStepIndex: Int?
    let createdAt: Date
    var expiresAt: Date

    init(
        id: UUID = UUID(),
        displayFrameInScreenSpace: CGRect,
        annotations: [DexterAnnotation],
        currentStepIndex: Int? = nil,
        createdAt: Date = Date(),
        lifetimeSeconds: TimeInterval = 90
    ) {
        self.id = id
        self.displayFrameInScreenSpace = displayFrameInScreenSpace
        self.annotations = annotations
        self.currentStepIndex = currentStepIndex
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(lifetimeSeconds)
    }
}
