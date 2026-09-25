//
//  DexterPointInvokeBanner.swift
//  leanring-buddy
//

import SwiftUI

struct DexterPointInvokeBanner: View {
    let session: DexterPointInvokeSession?
    let isPreparing: Bool
    var pointAskPresence: DexterPointAskPresenceState = .ready
    let onDismiss: () -> Void

    var body: some View {
        if isPreparing {
            preparingBanner
        } else if let session {
            activeBanner(session: session)
        }
    }

    private var preparingBanner: some View {
        HStack(spacing: DexterMetrics.space10) {
            ProgressView().controlSize(.small)
            DexterPointAskPresenceBadge(state: .thinking)
            Text("Capturing what you're pointing at…")
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
            Spacer()
        }
        .dexterCompanionInlineBannerChrome()
    }

    private func activeBanner(session: DexterPointInvokeSession) -> some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space8) {
            HStack {
                Text("Point + Ask")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterColors.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DexterColors.textTertiary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(DexterColors.inputBackground))
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .accessibilityLabel("Dismiss pointer context")
            }

            HStack(spacing: DexterMetrics.space8) {
                DexterPointAskPresenceBadge(state: pointAskPresence)
                Text(session.contextualIndicatorLabel)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterPastelColors.sky)
            }

            if let evidenceLine = semanticEvidenceSummary(for: session) {
                Text(evidenceLine)
                    .font(DexterTypography.monospacedCaption())
                    .foregroundColor(DexterColors.textTertiary)
            }

            if session.contextSnapshot.screenCaptureAvailability == .permissionMissing {
                Text("Screen recording permission is required before Dexter can see this area.")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.error)
            } else if session.screenCaptureSnapshots.isEmpty {
                Text("Screen context wasn't captured. Dexter will use app and window info.")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textSecondary)
            } else if session.userFacingSemanticTargetLabel != nil {
                Text("Screen and pointer context captured")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            } else {
                Text("Screen context captured")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }
        }
        .dexterCompanionInlineBannerChrome()
    }

    private func semanticEvidenceSummary(for session: DexterPointInvokeSession) -> String? {
        guard let target = session.pointerSemanticTarget else { return nil }
        let sources = target.evidence.map(\.source.rawValue).sorted()
        guard !sources.isEmpty else { return nil }
        return "Target from " + sources.joined(separator: ", ")
    }
}

private struct DexterPointAskPresenceBadge: View {
    let state: DexterPointAskPresenceState

    var body: some View {
        Text(state.userFacingLabel.uppercased())
            .font(DexterTypography.status())
            .foregroundColor(DexterColors.textOnAccent)
            .padding(.horizontal, DexterMetrics.space8)
            .padding(.vertical, DexterMetrics.space4)
            .background(
                Capsule(style: .continuous)
                    .fill(badgeColor.opacity(0.92))
            )
    }

    private var badgeColor: Color {
        switch state {
        case .ready:
            return DexterPastelColors.lavender
        case .targeted:
            return DexterPastelColors.sky
        case .thinking:
            return DexterPastelColors.blush
        }
    }
}
