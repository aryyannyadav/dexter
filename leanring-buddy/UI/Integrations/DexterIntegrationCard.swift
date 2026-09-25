//
//  DexterIntegrationCard.swift
//  leanring-buddy
//

import SwiftUI

struct DexterIntegrationCard: View {
    let integration: DexterIntegration
    var descriptionOverride: String?
    var onPrimaryAction: (() -> Void)?
    var onManage: (() -> Void)?

    private var presentation: DexterIntegrationCardPresentation {
        DexterIntegrationCardPresentation(integration: integration)
    }

    var body: some View {
        HStack(alignment: .top, spacing: DexterSpacing.md) {
            integrationIcon

            VStack(alignment: .leading, spacing: DexterSpacing.xs) {
                HStack(spacing: DexterSpacing.sm) {
                    Text(integration.name)
                        .font(DexterTypography.bodyMedium())
                        .foregroundColor(DexterSurfaceColors.textPrimary)
                    Spacer(minLength: 0)
                    statusBadge
                }

                Text(descriptionOverride ?? presentation.description)
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let primaryTitle = presentation.primaryActionTitle, let onPrimaryAction {
                    HStack(spacing: DexterSpacing.sm) {
                        Button(primaryTitle, action: onPrimaryAction)
                            .buttonStyle(.plain)
                            .font(DexterTypography.bodyMedium())
                            .foregroundColor(DexterPastelColors.lavender)
                            .pointerCursor()
                            .accessibilityLabel("\(primaryTitle) \(integration.name)")

                        if presentation.showsManage, let onManage {
                            Button("Manage", action: onManage)
                                .buttonStyle(.plain)
                                .font(DexterTypography.caption())
                                .foregroundColor(DexterColors.textTertiary)
                                .pointerCursor()
                                .accessibilityLabel("Manage \(integration.name)")
                        }
                    }
                    .padding(.top, DexterSpacing.xs)
                }
            }
        }
        .padding(DexterSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                .fill(DexterSurfaceColors.surface.opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.medium, style: .continuous)
                .stroke(DexterColors.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(integration.name), \(presentation.accessibilityStatus)")
    }

    private var integrationIcon: some View {
        DexterIntegrationIconView(
            integration: integration,
            size: 36,
            cornerRadius: DexterRadii.small
        )
    }

    private var statusBadge: some View {
        Text(presentation.statusLabel)
            .font(DexterTypography.metadata())
            .foregroundColor(presentation.statusForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(presentation.statusBackground)
            )
    }
}

struct DexterIntegrationCardPresentation {
    let integration: DexterIntegration

    var description: String {
        if integration.kind == .discoveryReference {
            return "Not available in Dexter yet."
        }
        if integration.id == "github" {
            return "Connect Dexter to your repositories for grounded GitHub context."
        }
        if integration.id == "browser" {
            return "Browser context from the app you're using (not a separate account login)."
        }
        if integration.id == "openclaw-gateway" {
            return "Dexter's computer runtime for verified actions on your Mac."
        }
        return integration.statusDetail ?? integration.subtitleLine
    }

    var statusLabel: String {
        if integration.kind == .discoveryReference {
            return "Coming later"
        }
        return integration.connectionState.userFacingLabel
    }

    var accessibilityStatus: String { statusLabel }

    var primaryActionTitle: String? {
        guard integration.kind == .operational else { return nil }
        switch integration.connectionState {
        case .connected:
            return integration.id == "github" ? "Manage" : nil
        case .needsAuthentication:
            return "Connect"
        case .notConnected, .connecting:
            return integration.id == "openclaw-gateway" ? "Reconnect" : "Connect"
        case .error, .unsupported:
            return "Open settings"
        }
    }

    var showsManage: Bool {
        integration.kind == .operational
            && integration.connectionState == .connected
            && integration.id == "github"
    }

    var systemImageName: String {
        switch integration.id {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "browser": return "globe"
        case "terminal": return "terminal"
        case "vscode": return "chevron.left.slash.chevron.right"
        case "openclaw-gateway": return "cpu"
        default: return "ellipsis.circle"
        }
    }

    var statusForeground: Color {
        switch integration.connectionState {
        case .connected:
            return DexterColors.textSecondary
        case .needsAuthentication, .connecting:
            return DexterPastelColors.lavender
        case .error:
            return DexterColors.textSecondary
        case .notConnected, .unsupported:
            return DexterColors.textTertiary
        }
    }

    var statusBackground: Color {
        switch integration.connectionState {
        case .connected:
            return Color.green.opacity(0.12)
        case .needsAuthentication:
            return DexterPastelColors.lavender.opacity(0.14)
        default:
            return DexterSurfaceColors.secondaryBackground
        }
    }
}
