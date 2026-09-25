//
//  DexterContextIndicator.swift
//  leanring-buddy
//

import SwiftUI

struct DexterContextIndicator: View {
    let uiState: DexterScreenContextUIState
    var contextualLabel: String?
    var compact: Bool = false
    var ultraCompact: Bool = false

    var body: some View {
        HStack(spacing: DexterMetrics.space6) {
            DexterStatusDot(tone: indicatorTone, showsSoftGlow: indicatorTone == .active && !ultraCompact)

            if !ultraCompact {
                Text(displayLabel)
                    .font(compact ? DexterTypography.caption() : DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                    .lineLimit(compact ? 1 : 2)
            }
        }
        .padding(.horizontal, compact ? DexterMetrics.space8 : 0)
        .padding(.vertical, compact ? DexterMetrics.space4 : 0)
        .background {
            if compact {
                Capsule(style: .continuous)
                    .fill(DexterColors.inputBackground.opacity(0.85))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(DexterColors.borderSubtle, lineWidth: 1)
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ultraCompact ? uiState.userFacingLabel : displayLabel)
    }

    private var displayLabel: String {
        if let contextualLabel, !contextualLabel.isEmpty {
            return compactLabel(contextualLabel)
        }
        return compactLabel(uiState.userFacingLabel)
    }

    private func compactLabel(_ rawLabel: String) -> String {
        let normalized = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if ultraCompact {
            if normalized.lowercased().contains("screen") { return "Screen" }
            if normalized.lowercased().contains("ready") { return "Ready" }
            if normalized.lowercased().contains("analyzing") { return "Analyzing" }
        }
        return normalized.uppercased()
    }

    private var indicatorTone: DexterStatusDot.Tone {
        switch uiState {
        case .ready:
            return .success
        case .analyzingScreen:
            return .active
        case .permissionRequired:
            return .warning
        case .unavailable:
            return .neutral
        }
    }
}
