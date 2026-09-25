//
//  DexterIntegrationsSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterIntegrationsSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @StateObject private var customConfigurationStore = DexterCustomConnectorConfigurationStore.shared
    @State private var searchText: String = ""
    @State private var isCustomConnectorSheetPresented = false
    @State private var isGitHubTokenSheetPresented = false

    private var integrationService: DexterIntegrationService {
        companionManager.dexterIntegrationService
    }

    private var filteredIntegrations: [DexterIntegration] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return integrationService.integrations }
        return integrationService.integrations.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        DexterSettingsPageContainer(
            title: "Integrations",
            subtitle: "Live connection state from OpenClaw, authorized context, and connectors you configure."
        ) {
            DexterSettingsSearchField(placeholder: "Search integrations", text: $searchText)

            HStack(spacing: 8) {
                DexterSettingsSecondaryButton(title: "Add custom connector") {
                    isCustomConnectorSheetPresented = true
                }
                DexterSettingsSecondaryButton(
                    title: integrationService.isRefreshing ? "Refreshing…" : "Refresh status"
                ) {
                    companionManager.refreshDexterIntegrations()
                }
                .disabled(integrationService.isRefreshing)
            }
            .padding(.top, 4)

            if integrationService.integrations.first(where: { $0.id == "github" })?.connectionState == .needsAuthentication
                || !DexterGitHubConnector.hasStoredPersonalAccessToken {
                DexterSettingsSecondaryButton(title: "Configure GitHub token") {
                    isGitHubTokenSheetPresented = true
                }
                .padding(.top, 4)
            }

            let operational = filteredIntegrations.filter { $0.kind == .operational }
            if !operational.isEmpty {
                DexterSettingsSection(title: "CONNECTED TOOLS") {
                    VStack(spacing: 10) {
                        ForEach(operational) { integration in
                            DexterIntegrationCard(
                                integration: integration,
                                onPrimaryAction: {
                                    handleIntegrationPrimary(integration)
                                },
                                onManage: integration.id == "github" ? {
                                    isGitHubTokenSheetPresented = true
                                } : nil
                            )
                        }
                    }
                }
            }

            DexterSettingsSection(title: operational.isEmpty ? nil : "ALL INTEGRATIONS") {
                ForEach(filteredIntegrations) { integration in
                    DexterIntegrationRow(
                        integration: integration,
                        onTestConnection: integration.kind == .operational && integration.id.hasPrefix("custom-")
                            ? { testCustomConnector(integration: integration) }
                            : nil
                    )
                    if integration.id != filteredIntegrations.last?.id {
                        DexterSettingsDivider()
                    }
                }
            }
        }
        .sheet(isPresented: $isCustomConnectorSheetPresented) {
            DexterCustomConnectorSheet(companionManager: companionManager)
        }
        .sheet(isPresented: $isGitHubTokenSheetPresented) {
            DexterGitHubTokenSheet(companionManager: companionManager)
        }
        .onAppear {
            companionManager.refreshDexterIntegrations()
        }
        .onChange(of: customConfigurationStore.configurations) { _, _ in
            companionManager.refreshDexterIntegrations()
        }
    }

    private func handleIntegrationPrimary(_ integration: DexterIntegration) {
        switch integration.id {
        case "github":
            isGitHubTokenSheetPresented = true
        case "openclaw-gateway":
            companionManager.refreshOpenClawGatewayConnection()
        default:
            break
        }
    }

    private func testCustomConnector(integration: DexterIntegration) {
        let uuidString = integration.id.replacingOccurrences(of: "custom-", with: "")
        guard let connectorIdentifier = UUID(uuidString: uuidString) else { return }
        Task {
            _ = await companionManager.dexterIntegrationService.testCustomConnector(identifier: connectorIdentifier)
            companionManager.refreshDexterIntegrations()
        }
    }
}

struct DexterIntegrationRow: View {
    let integration: DexterIntegration
    var onTestConnection: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DexterIntegrationIconView(integration: integration, size: 28, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(integration.name)
                    .font(DexterSettingsTypography.rowTitle())
                    .foregroundColor(DS.Colors.textPrimary)

                Text(integration.subtitleLine)
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if !integration.capabilities.isEmpty {
                    ForEach(integration.capabilities.prefix(3)) { capability in
                        Text("• \(capability.displayName): \(capability.isAvailable ? "available" : "unavailable")")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            if let onTestConnection {
                DexterSettingsSecondaryButton(title: "Test", action: onTestConnection)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DexterGitHubTokenSheet: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.dismiss) private var dismiss
    @State private var tokenDraft: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub personal access token")
                .font(.system(size: 18, weight: .semibold))

            Text("Dexter stores the token in the macOS Keychain and verifies it against api.github.com. OAuth is not implemented in this build.")
                .font(DexterSettingsTypography.pageSubtitle())
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("ghp_…", text: $tokenDraft)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
            }

            HStack {
                if DexterGitHubConnector.hasStoredPersonalAccessToken {
                    DexterSettingsSecondaryButton(title: "Remove token") {
                        removeToken()
                    }
                }
                Spacer()
                DexterSettingsSecondaryButton(title: "Cancel") { dismiss() }
                DexterSettingsSecondaryButton(title: "Save") {
                    saveToken()
                }
                .disabled(tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(DexterSettingsColors.contentBackground)
    }

    private func saveToken() {
        do {
            try companionManager.dexterIntegrationService.saveGitHubPersonalAccessToken(tokenDraft)
            tokenDraft = ""
            companionManager.refreshDexterIntegrations()
            dismiss()
        } catch {
            errorMessage = "Could not save the token to Keychain."
        }
    }

    private func removeToken() {
        do {
            try companionManager.dexterIntegrationService.deleteGitHubPersonalAccessToken()
            companionManager.refreshDexterIntegrations()
            dismiss()
        } catch {
            errorMessage = "Could not remove the token from Keychain."
        }
    }
}

struct DexterCustomConnectorSheet: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.dismiss) private var dismiss

    @State private var connectorName: String = ""
    @State private var connectorKind: DexterCustomConnectorKind = .mcp
    @State private var transport: DexterCustomConnectorTransport = .remoteServerURL
    @State private var serverURLString: String = ""
    @State private var localCommand: String = ""
    @State private var authenticationSecret: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add custom connector")
                .font(.system(size: 18, weight: .semibold))

            Text("Non-secret fields are saved locally. Authentication is stored in Keychain only.")
                .font(DexterSettingsTypography.pageSubtitle())
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Connector name", text: $connectorName)
                .textFieldStyle(.roundedBorder)

            Picker("Kind", selection: $connectorKind) {
                ForEach(DexterCustomConnectorKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            if connectorKind == .mcp {
                Picker("Transport", selection: $transport) {
                    Text("Server URL").tag(DexterCustomConnectorTransport.remoteServerURL)
                    Text("Local command").tag(DexterCustomConnectorTransport.localCommand)
                }

                if transport == .remoteServerURL {
                    TextField("https://…", text: $serverURLString)
                        .textFieldStyle(.roundedBorder)
                } else {
                    TextField("/path/to/mcp-server", text: $localCommand)
                        .textFieldStyle(.roundedBorder)
                }

                SecureField("Authentication (optional)", text: $authenticationSecret)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("Gateway URL or note (optional)", text: $serverURLString)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                DexterSettingsSecondaryButton(title: "Cancel") { dismiss() }
                DexterSettingsSecondaryButton(title: "Save") {
                    saveConnector()
                }
                .disabled(connectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(DexterSettingsColors.contentBackground)
    }

    private func saveConnector() {
        let configuration = DexterCustomConnectorConfiguration(
            name: connectorName,
            kind: connectorKind,
            transport: connectorKind == .mcp ? transport : .remoteServerURL,
            serverURLString: serverURLString,
            localCommand: localCommand
        )
        DexterCustomConnectorConfigurationStore.shared.addConfiguration(configuration)

        if !authenticationSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? companionManager.dexterIntegrationService.saveCustomConnectorAuthenticationSecret(
                connectorIdentifier: configuration.id,
                secret: authenticationSecret
            )
        }

        authenticationSecret = ""
        companionManager.refreshDexterIntegrations()
        dismiss()
    }
}
