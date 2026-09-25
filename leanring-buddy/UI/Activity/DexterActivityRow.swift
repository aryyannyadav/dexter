//
//  DexterActivityRow.swift
//  leanring-buddy
//

import SwiftUI

struct DexterActivityRow: View {
    let record: DexterActivityRecord
    var dexterName: String?
    var showsDexterLabel: Bool = false
    var onSelect: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(alignment: .top, spacing: DexterSpacing.md) {
                statusGlyph
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    if showsDexterLabel, let dexterName {
                        Text(dexterName)
                            .font(DexterTypography.caption())
                            .foregroundColor(DexterColors.textTertiary)
                    }

                    Text(record.title)
                        .font(DexterTypography.bodyMedium())
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(verificationLabel)
                            .font(DexterTypography.caption())
                            .foregroundColor(statusColor)

                        Text("·")
                            .foregroundColor(DexterColors.textTertiary)
                            .font(DexterTypography.caption())

                        Text(DexterActivityPresentation.relativeTimestampLabel(for: record.timestamp))
                            .font(DexterTypography.caption())
                            .foregroundColor(DexterColors.textTertiary)
                    }

                    if let summary = secondarySummary {
                        Text(summary)
                            .font(DexterTypography.caption())
                            .foregroundColor(DexterColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DexterSpacing.md)
            .dexterCardSurface(accentColor: statusColor, isHovered: isHovered, cornerRadius: DexterRadii.medium)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel(DexterActivityPresentation.accessibilityLabel(for: record))
    }

    @ViewBuilder
    private var statusGlyph: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
            Image(systemName: DexterActivityPresentation.systemImageName(for: record.kind, status: record.status))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(statusColor)
        }
    }

    private var verificationLabel: String {
        switch record.status {
        case .verified, .completed:
            return "✓ Verified"
        case .partiallyVerified:
            return "Partially verified"
        case .failed, .timedOut:
            return "× Not completed"
        case .cancelled:
            return "− Cancelled"
        case .needsPermission:
            return "Needs permission"
        case .running:
            return "In progress"
        }
    }

    private var secondarySummary: String? {
        guard let summary = record.summary, !summary.isEmpty else { return nil }
        if record.kind == .memory {
            return "“\(summary)”"
        }
        if record.kind == .action {
            return nil
        }
        return summary
    }

    private var statusColor: Color {
        switch record.status {
        case .failed, .timedOut:
            return DexterPastelColors.coral
        case .needsPermission:
            return DexterColors.textSecondary
        case .cancelled:
            return DexterColors.textTertiary
        case .partiallyVerified:
            return DexterPastelColors.peach
        case .verified, .completed:
            return DexterPastelColors.mint
        case .running:
            return DexterPastelColors.sky
        }
    }
}
