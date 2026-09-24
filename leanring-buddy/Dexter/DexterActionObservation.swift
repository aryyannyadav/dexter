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
    let browserState: DexterBrowserStateSnapshot
    let hasAccessibilityObservation: Bool
    let observedAt: Date

    static let empty = DexterActionObservationSnapshot(
        activeApplicationBundleIdentifier: nil,
        activeApplicationLocalizedName: nil,
        activeWindowTitle: nil,
        pointerElementTitle: nil,
        pointerElementRoleDescription: nil,
        pointerElementValueDescription: nil,
        browserState: .empty,
        hasAccessibilityObservation: false,
        observedAt: .distantPast
    )

    static func from(context: DexterContext) -> DexterActionObservationSnapshot {
        let hint = context.attention.accessibilityHintAtPointer
        let browserState = DexterBrowserStateCollector.collect(
            activeApplication: context.activeApplication,
            activeWindow: context.activeWindow,
            selectedText: context.selectedText,
            browserContext: nil,
            currentTaskDescription: context.currentTask.currentTaskDescription,
            pointerSemanticTargetLabel: context.pointer?.semanticTarget?.primaryLabel
        )
        return DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: context.activeApplication.bundleIdentifier,
            activeApplicationLocalizedName: context.activeApplication.localizedName,
            activeWindowTitle: context.activeWindow.title,
            pointerElementTitle: hint.title,
            pointerElementRoleDescription: hint.roleDescription,
            pointerElementValueDescription: hint.valueDescription,
            browserState: browserState,
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

        let browserState = DexterBrowserStateCollector.collect(
            activeApplication: environment.activeApplication,
            activeWindow: environment.activeWindow,
            selectedText: environment.selectedText,
            browserContext: DexterBrowserContextCollector.collect(
                activeApplication: environment.activeApplication,
                activeWindow: environment.activeWindow
            ),
            currentTaskDescription: nil,
            pointerSemanticTargetLabel: hint.title
        )

        return DexterActionObservationSnapshot(
            activeApplicationBundleIdentifier: environment.activeApplication.bundleIdentifier,
            activeApplicationLocalizedName: environment.activeApplication.localizedName,
            activeWindowTitle: environment.activeWindow.title,
            pointerElementTitle: hint.title,
            pointerElementRoleDescription: hint.roleDescription,
            pointerElementValueDescription: hint.valueDescription,
            browserState: browserState,
            hasAccessibilityObservation: environment.activeApplication.availability == .available,
            observedAt: Date()
        )
    }
}
