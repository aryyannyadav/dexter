//
//  DexterSettingsView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterSettingsView: View {
    @ObservedObject var companionManager: CompanionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)

                settingsSection(title: "General") {
                    Toggle(isOn: Binding(
                        get: { companionManager.isDexterCursorEnabled },
                        set: { companionManager.setDexterCursorEnabled($0) }
                    )) {
                        settingsRowLabel("Show Dexter cursor overlay")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)

                    Toggle(isOn: Binding(
                        get: { companionManager.autoApproveLowRiskActions },
                        set: { companionManager.autoApproveLowRiskActions = $0 }
                    )) {
                        settingsRowLabel("Auto-approve low-risk actions")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)
                }

                settingsSection(title: "AI") {
                    claudeModelRow

                    Divider().background(DS.Colors.borderSubtle)

                    ollamaPlaceholderBlock
                }

                settingsSection(title: "Voice") {
                    Toggle(isOn: Binding(
                        get: { companionManager.isPushToTalkEnabled },
                        set: { companionManager.isPushToTalkEnabled = $0 }
                    )) {
                        settingsRowLabel("Push-to-talk")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)

                    Toggle(isOn: Binding(
                        get: { companionManager.isSpokenResponsesEnabled },
                        set: { companionManager.isSpokenResponsesEnabled = $0 }
                    )) {
                        settingsRowLabel("Spoken responses")
                    }
                    .toggleStyle(.switch)
                    .tint(DexterIdentity.accent)

                    HStack {
                        settingsRowLabel("Speech-to-text")
                        Spacer()
                        Text(companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                            .font(DexterIdentity.Typography.monoCaption())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }

                settingsSection(title: "Context & Privacy") {
                    DexterPermissionList(companionManager: companionManager)
                    DexterMemoryManagementView(companionManager: companionManager)
                        .onAppear { companionManager.reloadDexterMemoryPresentation() }
                }

                settingsSection(title: "Shortcuts") {
                    Text("Hold Control + Option to talk to Dexter from anywhere.")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsSection(title: "About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DexterProductCopy.name)
                            .font(DexterIdentity.Typography.title())
                            .foregroundColor(DS.Colors.textPrimary)
                        Text(DexterProductCopy.tagline)
                            .font(DexterIdentity.Typography.body())
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                            .font(DexterIdentity.Typography.monoCaption())
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DS.Colors.background)
    }

    private var claudeModelRow: some View {
        HStack {
            settingsRowLabel("Cloud model")
            Spacer()
            HStack(spacing: 0) {
                modelButton("Sonnet", id: "claude-sonnet-4-6")
                modelButton("Opus", id: "claude-opus-4-6")
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(DS.Colors.surface2))
        }
    }

    private var ollamaPlaceholderBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local provider (coming soon)")
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)

            settingsKeyValueRow(label: "Provider", value: "Ollama")
            settingsKeyValueRow(label: "Status", value: "Not connected")
            settingsKeyValueRow(label: "Model", value: "Qwen3.5 9B")
            settingsKeyValueRow(label: "Endpoint", value: "http://localhost:11434")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: DS.CornerRadius.medium).fill(DS.Colors.surface2))
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.medium)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func modelButton(_ label: String, id: String) -> some View {
        let selected = companionManager.selectedModel == id
        return Button(label) { companionManager.setSelectedModel(id) }
            .font(DexterIdentity.Typography.monoCaption())
            .foregroundColor(selected ? DexterIdentity.accent : DS.Colors.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? DexterIdentity.accentSubtle : Color.clear)
            .buttonStyle(.plain)
            .pointerCursor()
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(DexterIdentity.Typography.sectionLabel())
                .foregroundColor(DS.Colors.textTertiary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                    .fill(DS.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func settingsRowLabel(_ text: String) -> some View {
        Text(text)
            .font(DexterIdentity.Typography.body())
            .foregroundColor(DS.Colors.textSecondary)
    }

    private func settingsKeyValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DexterIdentity.Typography.body())
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DexterIdentity.Typography.monoCaption())
                .foregroundColor(DS.Colors.textTertiary)
        }
    }
}
