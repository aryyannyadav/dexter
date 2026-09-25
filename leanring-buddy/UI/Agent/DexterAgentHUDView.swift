//
//  DexterAgentHUDView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterAgentHUDView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var hudController: DexterAgentHUDController

    private var presentation: DexterAgentHUDPresentation {
        hudController.presentation
    }

    var body: some View {
        Group {
            switch presentation.mode {
            case .hidden:
                EmptyView()
            case .permission:
                permissionCard
            case .running:
                runningCard
            case .result:
                resultCard
            case .failure:
                failureCard
            }
        }
    }

    private var runningCard: some View {
        hudShell {
            header
            Text(presentation.operationLabel)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterPastelColors.lavender)
            if let progressCaption = presentation.progressCaption {
                Text(progressCaption)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }
            if let fraction = presentation.progressFraction {
                ProgressView(value: fraction)
                    .tint(DexterPastelColors.lavender)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            if let openClawLine = presentation.openClawStatusLine {
                Text(openClawLine)
                    .font(DexterTypography.monospacedCaption())
                    .foregroundColor(DexterColors.textMuted)
                    .lineLimit(1)
            }
            stopButton
        }
    }

    private var permissionCard: some View {
        hudShell {
            header
            Text("Dexter wants to control your Mac.")
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterColors.textPrimary)
            Text(presentation.operationLabel)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
            if let whereCaption = presentation.progressCaption {
                Text(whereCaption)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }
            if let why = presentation.failureDetail {
                Text(why)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }
            HStack(spacing: DexterMetrics.space8) {
                DexterButton(title: "Allow once") {
                    companionManager.approveAgentPermissionFromHUD(allowAlwaysForLowRisk: false)
                }
                if presentation.canOfferAlwaysAllow {
                    DexterSecondaryButton(title: "Always allow") {
                        companionManager.approveAgentPermissionFromHUD(allowAlwaysForLowRisk: true)
                    }
                }
                DexterSecondaryButton(title: "Not now") {
                    companionManager.cancelPendingActionConfirmation()
                }
            }
        }
    }

    private var resultCard: some View {
        hudShell {
            header
            Text(presentation.verificationResultLabel ?? "Could not verify")
                .font(DexterTypography.title())
                .foregroundColor(
                    presentation.verificationResultLabel == "Verified"
                        ? DexterColors.success
                        : DexterColors.warning
                )
            if let caption = presentation.progressCaption, !caption.isEmpty {
                Text(caption)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }
            DexterSecondaryButton(title: "Dismiss") {
                hudController.dismissTerminalCard()
            }
        }
    }

    private var failureCard: some View {
        hudShell {
            header
            Text(presentation.failureHeadline ?? "Dexter couldn't complete that action.")
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterColors.textPrimary)
            if let detail = presentation.failureDetail {
                Text(detail)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DexterMetrics.space8) {
                DexterSecondaryButton(title: "Retry") {
                    companionManager.retryLastAgentActionFromHUD()
                }
                DexterSecondaryButton(title: "Explain") {
                    companionManager.explainLastAgentFailureFromHUD()
                }
                DexterSecondaryButton(title: "Cancel") {
                    hudController.dismissTerminalCard()
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: DexterMetrics.space10) {
            DexterAvatarCompanionView(companionManager: companionManager, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dexter")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterColors.textPrimary)
                Text(presentation.taskName)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var stopButton: some View {
        Button("Stop") {
            Task {
                await companionManager.stopActiveAgentOperationFromHUD()
            }
        }
        .buttonStyle(.plain)
        .font(DexterTypography.bodyMedium())
        .foregroundColor(DexterColors.error)
        .pointerCursor()
    }

    private func hudShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space12) {
            content()
        }
        .padding(DexterMetrics.space16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusXL, style: .continuous)
                .fill(DexterColors.cardBackgroundElevated.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusXL, style: .continuous)
                .stroke(DexterPastelColors.lavender.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
    }
}
