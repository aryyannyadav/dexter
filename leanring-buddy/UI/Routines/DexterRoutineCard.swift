//
//  DexterRoutineCard.swift
//  leanring-buddy
//

import SwiftUI

struct DexterRoutineCard: View {
    let routine: DexterRoutine
    let profile: DexterProfile?
    let characterState: DexterCharacterState
    var onToggleEnabled: (Bool) -> Void
    var onOpenDetails: () -> Void
    var onRunNow: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DexterSpacing.sm) {
            routineCharacterBadge

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(routine.name)
                        .font(DexterTypography.bodyMedium())
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    statusBadge
                }

                if !routine.description.isEmpty {
                    Text(routine.description)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textSecondary)
                        .lineLimit(2)
                }

                Text(routine.trigger.summaryLabel)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)

                if let nextRunLabel = nextRunLabel {
                    Text(nextRunLabel)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                }
            }

            VStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { routine.isEnabled },
                    set: { onToggleEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .tint(DexterPastelColors.lavender)
                .accessibilityLabel("Enable \(routine.name)")

                Menu {
                    if let onRunNow {
                        Button("Run now") { onRunNow() }
                    }
                    Button("Details") { onOpenDetails() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DexterColors.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .pointerCursor()
                .accessibilityLabel("More options for \(routine.name)")
            }
        }
        .padding(DexterSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusXL, style: .continuous)
                .fill(DexterSurfaceColors.surfaceElevated.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusXL, style: .continuous)
                .stroke(DexterColors.borderSubtle, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: DexterMetrics.radiusXL, style: .continuous))
        .onTapGesture { onOpenDetails() }
        .pointerCursor()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var routineCharacterBadge: some View {
        if let profile,
           let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
            DexterCharacterView(
                definition: definition,
                appearance: profile.characterAppearance,
                state: characterState,
                size: .custom(28),
                presentationMode: .avatar,
                profileNameForAccessibility: profile.name
            )
            .frame(width: 32, height: 32)
        } else {
            DexterLogo(size: 24, style: .standard, animated: false)
                .frame(width: 32, height: 32)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(routine.status.displayName)
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textSecondary)
        }
    }

    private var statusColor: Color {
        switch routine.status {
        case .active: return DexterPastelColors.mint
        case .paused: return DexterColors.textTertiary
        case .completed: return DexterColors.textTertiary
        case .failed: return .orange
        }
    }

    private var nextRunLabel: String? {
        guard routine.trigger.kind == .schedule, let nextRunAt = routine.nextRunAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Next · \(formatter.localizedString(for: nextRunAt, relativeTo: Date()))"
    }

    private var accessibilitySummary: String {
        "\(routine.name), \(routine.status.displayName), \(routine.trigger.summaryLabel)"
    }
}
