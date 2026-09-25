//
//  DexterProductComponents.swift
//  leanring-buddy
//
//  Reusable Dexter product UI primitives (Phase 1 design system).
//

import SwiftUI

// MARK: - Card

struct DexterCard<Content: View>: View {
    var padding: CGFloat = DexterMetrics.space16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                    .fill(DexterColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                    .stroke(DexterColors.borderSubtle, lineWidth: 1)
            )
    }
}

// MARK: - Buttons

struct DexterButton: View {
    let title: String
    var isFullWidth: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterColors.textOnAccent)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, DexterMetrics.space16)
                .frame(height: DexterMetrics.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DexterPastelColors.sky.opacity(isHovered ? 0.9 : 0.75),
                                    DexterPastelColors.lavender.opacity(isHovered ? 0.85 : 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(
                    color: DexterPastelColors.lavender.opacity(isHovered ? 0.35 : 0.15),
                    radius: isHovered ? 10 : 4,
                    y: 2
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
    }
}

struct DexterSecondaryButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterColors.textPrimary)
                .padding(.horizontal, DexterMetrics.space12)
                .frame(height: DexterMetrics.buttonHeightCompact)
                .background(
                    RoundedRectangle(cornerRadius: DexterMetrics.radiusSmall, style: .continuous)
                        .fill(isHovered ? DexterColors.hoverOverlay : DexterColors.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DexterMetrics.radiusSmall, style: .continuous)
                        .stroke(DexterColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
    }
}

struct DexterIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DexterColors.textSecondary)
                .frame(width: DexterMetrics.iconButtonSize, height: DexterMetrics.iconButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                        .fill(isHovered ? DexterColors.hoverOverlay : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Toggle

struct DexterToggle: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: DexterMetrics.space12) {
            VStack(alignment: .leading, spacing: DexterMetrics.space2) {
                Text(title)
                    .font(DexterTypography.body())
                    .foregroundColor(DexterColors.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DexterTypography.secondary())
                        .foregroundColor(DexterColors.textSecondary)
                }
            }
            Spacer(minLength: DexterMetrics.space8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(DexterMetrics.toggleScale)
                .tint(DexterPastelColors.lavender)
        }
        .frame(minHeight: DexterMetrics.rowHeight, alignment: .center)
    }
}

// MARK: - Status

struct DexterStatusDot: View {
    enum Tone {
        case neutral
        case active
        case success
        case warning
        case error
    }

    var tone: Tone = .neutral
    var showsSoftGlow: Bool = false

    var body: some View {
        ZStack {
            if showsSoftGlow && tone == .active {
                Circle()
                    .fill(DexterPastelColors.lavender.opacity(0.45))
                    .frame(width: 12, height: 12)
                    .blur(radius: 3)
            }
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .accessibilityHidden(true)
    }

    private var color: Color {
        switch tone {
        case .neutral:
            return DexterColors.textMuted
        case .active:
            return DexterPastelColors.lavender
        case .success:
            return DexterColors.success
        case .warning:
            return DexterColors.warning
        case .error:
            return DexterColors.error
        }
    }
}

struct DexterStatusPill: View {
    let label: String
    var tone: DexterStatusDot.Tone = .neutral
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: DexterMetrics.space6) {
            DexterStatusDot(tone: isActive ? .active : tone, showsSoftGlow: isActive)
            Text(label.uppercased())
                .font(DexterTypography.status())
                .foregroundColor(isActive ? DexterPastelColors.lavender : DexterColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, DexterMetrics.space10)
        .frame(height: DexterMetrics.statusPillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(isActive ? DexterPastelColors.lavender.opacity(0.14) : DexterColors.inputBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isActive ? DexterPastelColors.lavender.opacity(0.38) : DexterColors.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Divider

struct DexterDivider: View {
    var body: some View {
        Rectangle()
            .fill(DexterColors.border.opacity(0.65))
            .frame(height: 1)
    }
}

// MARK: - Navigation row (sidebar / lists)

struct DexterNavRow: View {
    let systemImage: String
    let title: String
    let isSelected: Bool
    var showsTrailingDot: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DexterMetrics.space8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(DexterTypography.bodyMedium())
                Spacer(minLength: 0)
                if showsTrailingDot {
                    DexterStatusDot(tone: .active, showsSoftGlow: true)
                }
            }
            .foregroundColor(isSelected ? DexterPastelColors.lavender : DexterColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DexterMetrics.space12)
            .padding(.vertical, DexterMetrics.space10)
            .background(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                    .fill(rowBackground)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(DexterPastelColors.lavender)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
    }

    private var rowBackground: Color {
        if isSelected { return DexterPastelColors.lavender.opacity(0.14) }
        if isHovered { return DexterColors.hoverOverlay }
        return Color.clear
    }
}

// MARK: - Search & chips

struct DexterSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: DexterMetrics.space8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DexterColors.textTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textPrimary)
        }
        .padding(.horizontal, DexterMetrics.space10)
        .frame(height: DexterMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                .fill(DexterColors.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusMedium, style: .continuous)
                .stroke(DexterColors.border, lineWidth: 1)
        )
    }
}

struct DexterChip: View {
    let title: String
    var isSelected: Bool = false
    let action: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    chipLabel
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
                .pointerCursor()
            } else {
                chipLabel
            }
        }
    }

    private var chipLabel: some View {
        Text(title)
            .font(DexterTypography.secondary())
            .foregroundColor(isSelected ? DexterColors.textPrimary : DexterColors.textSecondary)
            .padding(.horizontal, DexterMetrics.space10)
            .padding(.vertical, DexterMetrics.space6)
            .background(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusSmall, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DexterMetrics.radiusSmall, style: .continuous)
                    .stroke(isSelected ? DexterPastelColors.lavender.opacity(0.38) : DexterColors.border, lineWidth: 1)
            )
    }

    private var backgroundFill: Color {
        if isSelected { return DexterColors.selectedOverlay }
        if isHovered { return DexterColors.hoverOverlay }
        return DexterColors.inputBackground
    }
}

// MARK: - Empty state (generic shell)

struct DexterEmptyState: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space20) {
            HStack(spacing: DexterMetrics.space12) {
                DexterLogo(size: DexterMetrics.logoSizeSidebar, style: .glow, animated: true)
                VStack(alignment: .leading, spacing: DexterMetrics.space6) {
                    Text(title)
                        .font(DexterTypography.title())
                        .foregroundColor(DexterColors.textPrimary)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DexterTypography.secondary())
                            .foregroundColor(DexterColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(DexterColors.textTertiary)
                    .accessibilityHidden(true)
            }

            if let actionTitle, let action {
                DexterButton(title: actionTitle, action: action)
            }
        }
        .frame(maxWidth: DexterMetrics.contentMaxWidth, alignment: .leading)
    }
}
