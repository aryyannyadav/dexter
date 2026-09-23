//
//  DexterActionObservation.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics
import Foundation

struct DexterActionObservationSnapshot: Equatable {
    let activeApplicationBundleIdentifier: String?
    let activeApplicationLocalizedName: String?
    let activeWindowTitle: String?
    let pointerElementTitle: String?
    let pointerElementRoleDescription: String?
    let pointerElementValueDescription: String?
    let hasAccessibilityObservation: Bool
    let observedAt: Date

    static let empty = DexterActionObservationSnapshot(
        activeApplicationBundleIdentifier: nil,
        activeApplicationLocalizedName: nil,
        activeWindowTitle: nil,
        pointerElementTitle: nil,
        pointerElementRoleDescription: nil,
        pointerElementValueDescription: nil,
        hasAccessibilityObservation: false,
        observedAt: .distantPast
    )

    static func from(context: DexterContext) -> DexterActionObservationSnapshot {
        let hint = context.attention.accessibilityHintAtPointer
        return DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: context.activeApplication.bundleIdentifier,
            activeApplicationLocalizedName: context.activeApplication.localizedName,
            activeWindowTitle: context.activeWindow.title,
            pointerElementTitle: hint.title,
            pointerElementRoleDescription: hint.roleDescription,
            pointerElementValueDescription: hint.valueDescription,
            hasAccessibilityObservation: context.activeApplication.availability == .available,
            observedAt: Date()
        )
    }
}

protocol DexterActionContextObserver: AnyObject {
    func observeCurrentEnvironment(
        pointerLocationInScreenSpace: CGPoint,
        hasAccessibilityPermission: Bool
    ) -> DexterActionObservationSnapshot
}

@MainActor
final class MacDexterActionContextObserver: DexterActionContextObserver {
    func observeCurrentEnvironment(
        pointerLocationInScreenSpace: CGPoint,
        hasAccessibilityPermission: Bool
    ) -> DexterActionObservationSnapshot {
        let environment = DexterEnvironmentContextCollector.collect(
            hasAccessibilityPermission: hasAccessibilityPermission,
            pointerLocationInScreenSpace: pointerLocationInScreenSpace
        )

        let hint = DexterPointerAccessibilityHintCollector.collectHint(
            hasAccessibilityPermission: hasAccessibilityPermission,
            pointerLocationInScreenSpace: pointerLocationInScreenSpace
        )

        return DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: environment.activeApplication.bundleIdentifier,
            activeApplicationLocalizedName: environment.activeApplication.localizedName,
            activeWindowTitle: environment.activeWindow.title,
            pointerElementTitle: hint.title,
            pointerElementRoleDescription: hint.roleDescription,
            pointerElementValueDescription: hint.valueDescription,
            hasAccessibilityObservation: environment.activeApplication.availability == .available,
            observedAt: Date()
        )
    }
}
