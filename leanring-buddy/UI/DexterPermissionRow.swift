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

    @State private var isGrantHovered = false

    var body: some View {
        HStack(spacing: DexterMetrics.space12) {
            DexterStatusDot(tone: isGranted ? .success : .neutral)

            Text(title)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textPrimary)

            Spacer()

            if isGranted {
                Text("Ready")
                    .font(DexterTypography.status())
                    .foregroundColor(DexterColors.success)
            } else if let grantAction {
                Button("Allow", action: grantAction)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterPastelColors.lavender)
                    .padding(.horizontal, DexterMetrics.space8)
                    .padding(.vertical, DexterMetrics.space4)
                    .background(
                        RoundedRectangle(cornerRadius: DexterMetrics.radiusSmall, style: .continuous)
                            .fill(isGrantHovered ? DexterPastelColors.lavender.opacity(0.14) : Color.clear)
                    )
                    .buttonStyle(.plain)
                    .onHover { isGrantHovered = $0 }
                    .pointerCursor()
            }
        }
        .padding(.vertical, DexterMetrics.space8)
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
                    companionManager.requestAccessibilityPermissionFromPanel()
                }
            )

            DexterPermissionRow(
                title: "Screen Recording",
                isGranted: companionManager.hasScreenRecordingPermission,
                grantAction: {
                    companionManager.requestScreenRecordingPermissionFromPanel()
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
