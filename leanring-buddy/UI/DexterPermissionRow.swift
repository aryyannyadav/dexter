//
//  DexterPermissionRow.swift
//  leanring-buddy
//

import AVFoundation
import AppKit
import SwiftUI

struct DexterPermissionRow: View {
    let title: String
    let isGranted: Bool
    var grantAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isGranted ? DS.Colors.success : DS.Colors.textTertiary)
                .font(.system(size: 14))

            Text(title)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)

            Spacer()

            if isGranted {
                Text("Granted")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.success)
            } else if let grantAction {
                Button("Grant", action: grantAction)
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DexterIdentity.accent)
                    .buttonStyle(.plain)
                    .pointerCursor()
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct DexterPermissionList: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        VStack(spacing: 0) {
            DexterPermissionRow(
                title: "Microphone",
                isGranted: companionManager.hasMicrophonePermission,
                grantAction: {
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    if status == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )

            DexterPermissionRow(
                title: "Accessibility",
                isGranted: companionManager.hasAccessibilityPermission,
                grantAction: {
                    _ = companionManager.requestAccessibilityPermissionFromPanel()
                }
            )

            DexterPermissionRow(
                title: "Screen Recording",
                isGranted: companionManager.hasScreenRecordingPermission,
                grantAction: {
                    _ = companionManager.requestScreenRecordingPermissionFromPanel()
                }
            )

            if companionManager.hasScreenRecordingPermission {
                DexterPermissionRow(
                    title: "Screen Content",
                    isGranted: companionManager.hasScreenContentPermission,
                    grantAction: { companionManager.requestScreenContentPermission() }
                )
            }
        }
    }
}
