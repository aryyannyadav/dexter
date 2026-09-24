//
//  DexterPointInvokeBanner.swift
//  leanring-buddy
//

import SwiftUI

struct DexterPointInvokeBanner: View {
    let session: DexterPointInvokeSession?
    let isPreparing: Bool
    let onDismiss: () -> Void

    var body: some View {
        if isPreparing {
            preparingBanner
        } else if let session {
            activeBanner(session: session)
        }
    }

    private var preparingBanner: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Capturing what you're pointing at…")
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                .fill(DS.Colors.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                .stroke(DexterIdentity.accentBorder, lineWidth: 1)
        )
    }

    private func activeBanner(session: DexterPointInvokeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ask Dexter about this.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .accessibilityLabel("Dismiss pointer context")
            }

            Text(session.contextualIndicatorLabel)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DexterIdentity.accent)

            if session.contextSnapshot.screenCaptureAvailability == .permissionMissing {
                Text("Screen recording permission is required before Dexter can see this area.")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.destructiveText)
            } else if session.screenCaptureSnapshots.isEmpty {
                Text("Screen context wasn't captured. Dexter will explain what it can from app and window info only.")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.textSecondary)
            } else {
                Text("Screen context captured")
                    .font(DexterIdentity.Typography.monoCaption())
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                .fill(DexterIdentity.accentSubtle.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                .stroke(DexterIdentity.accentBorder, lineWidth: 1)
        )
    }
}
