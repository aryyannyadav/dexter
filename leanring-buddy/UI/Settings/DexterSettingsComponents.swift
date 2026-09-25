//
//  DexterSettingsComponents.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSettingsPageContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DexterSettingsMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(DexterSettingsTypography.pageTitle())
                        .foregroundColor(DS.Colors.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DexterSettingsTypography.pageSubtitle())
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                content()
            }
            .padding(.horizontal, DexterSettingsMetrics.contentPaddingHorizontal)
            .padding(.top, DexterSettingsMetrics.contentPaddingTop)
            .padding(.bottom, 40)
            .frame(maxWidth: DexterSettingsMetrics.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DexterSettingsColors.contentBackground)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [DexterPastelColors.lavender.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        }
    }
}

struct DexterSettingsSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title, !title.isEmpty {
                Text(title.uppercased())
                    .font(DexterSettingsTypography.sectionTitle())
                    .foregroundColor(DS.Colors.textTertiary)
            }

            VStack(spacing: 0) {
                content()
            }
        }
    }
}

struct DexterSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DexterSettingsColors.separator)
            .frame(height: 1)
    }
}

struct DexterSettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DexterSettingsTypography.rowSubtitle())
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .scaleEffect(DexterSettingsMetrics.toggleScale)
                .tint(DexterPastelColors.lavender)
        }
        .frame(minHeight: DexterSettingsMetrics.rowHeight, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct DexterSettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(DexterSettingsTypography.rowTitle())
                .foregroundColor(DS.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(DexterSettingsTypography.secondaryValue())
                .foregroundColor(DS.Colors.textTertiary)
        }
        .frame(minHeight: DexterSettingsMetrics.rowCompactHeight, alignment: .center)
    }
}

struct DexterSettingsSecondaryButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? DexterSettingsColors.rowHover : DexterSettingsColors.searchFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(DexterSettingsColors.searchFieldBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointerCursor()
    }
}

struct DexterSettingsSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DexterSettingsTypography.rowTitle())
                .foregroundColor(DS.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .frame(height: DexterSettingsMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: DexterSettingsMetrics.searchFieldCornerRadius, style: .continuous)
                .fill(DexterSettingsColors.searchFieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterSettingsMetrics.searchFieldCornerRadius, style: .continuous)
                .stroke(DexterSettingsColors.searchFieldBorder, lineWidth: 1)
        )
    }
}

struct DexterSettingsTextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var onCommit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DexterSettingsTypography.rowTitle())
                .foregroundColor(DS.Colors.textPrimary)
            TextField(placeholder, text: $text, onCommit: onCommit)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(DS.Colors.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: DexterSettingsMetrics.searchFieldHeight)
                .background(
                    RoundedRectangle(cornerRadius: DexterSettingsMetrics.searchFieldCornerRadius, style: .continuous)
                        .fill(DexterSettingsColors.searchFieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DexterSettingsMetrics.searchFieldCornerRadius, style: .continuous)
                        .stroke(DexterSettingsColors.searchFieldBorder, lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }
}

struct DexterSettingsPlaceholderNotice: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DexterSettingsTypography.rowSubtitle())
            .foregroundColor(DS.Colors.textTertiary)
            .padding(.vertical, 8)
    }
}
