//
//  DexterHomeCompactStatusStrip.swift
//  leanring-buddy
//

import SwiftUI

/// Lightweight status row — does not dominate the chat column.
struct DexterHomeCompactStatusStrip: View {
    @ObservedObject var runtimeUIStateStore: DexterRuntimeUIStateStore

    var body: some View {
        if shouldShowRuntimeStatus {
            runtimeChip
        }
    }

    private var shouldShowRuntimeStatus: Bool {
        switch runtimeUIStateStore.currentState {
        case .idle, .done, .cancelled:
            return false
        case .failed:
            return runtimeUIStateStore.failurePresentation != nil
        default:
            return true
        }
    }

    @ViewBuilder
    private var runtimeChip: some View {
        HStack(spacing: DexterMetrics.space8) {
            if runtimeUIStateStore.currentState == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DexterColors.warning)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Text(compactStatusText)
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DexterMetrics.space12)
        .padding(.vertical, DexterMetrics.space8)
        .background(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                .fill(DexterColors.inputBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                .stroke(DexterColors.borderSubtle, lineWidth: 1)
        )
    }

    private var compactStatusText: String {
        if let failure = runtimeUIStateStore.failurePresentation {
            return failure.whatFailed
        }
        let detail = runtimeUIStateStore.statusDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty {
            return detail
        }
        return runtimeUIStateStore.currentState == .verifying ? "Verifying…" : "Working…"
    }
}
