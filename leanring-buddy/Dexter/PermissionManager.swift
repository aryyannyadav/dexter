//
//  PermissionManager.swift
//  leanring-buddy
//

import AVFoundation
import Foundation

struct DexterPermissionSnapshot: Equatable {
    var hasAccessibilityPermission: Bool
    var hasScreenRecordingPermission: Bool
    var hasMicrophonePermission: Bool
    var hasScreenContentPermission: Bool

    var allRequiredPermissionsGranted: Bool {
        hasAccessibilityPermission
            && hasScreenRecordingPermission
            && hasMicrophonePermission
            && hasScreenContentPermission
    }
}

/// macOS permission checks and presentation flows for Dexter.
protocol PermissionManager: AnyObject {
    func currentPermissionSnapshot(hasPersistedScreenContentGrant: Bool) -> DexterPermissionSnapshot
    @discardableResult
    func requestAccessibilityPermission() -> PermissionRequestPresentationDestination
    @discardableResult
    func requestScreenRecordingPermission() -> PermissionRequestPresentationDestination
}

@MainActor
final class DexterPermissionManager: PermissionManager {
    func currentPermissionSnapshot(hasPersistedScreenContentGrant: Bool) -> DexterPermissionSnapshot {
        let microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        return DexterPermissionSnapshot(
            hasAccessibilityPermission: WindowPositionManager.hasAccessibilityPermission(),
            hasScreenRecordingPermission: WindowPositionManager.hasScreenRecordingPermission(),
            hasMicrophonePermission: microphoneAuthorized,
            hasScreenContentPermission: hasPersistedScreenContentGrant
        )
    }

    @discardableResult
    func requestAccessibilityPermission() -> PermissionRequestPresentationDestination {
        WindowPositionManager.requestAccessibilityPermission()
    }

    @discardableResult
    func requestScreenRecordingPermission() -> PermissionRequestPresentationDestination {
        WindowPositionManager.requestScreenRecordingPermission()
    }
}
