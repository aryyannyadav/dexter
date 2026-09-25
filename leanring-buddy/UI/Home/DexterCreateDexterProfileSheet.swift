//
//  DexterCreateDexterProfileSheet.swift
//  leanring-buddy
//

import SwiftUI

struct DexterCreateDexterProfileSheet: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.dismiss) private var dismiss

    @State private var purposeDraft: String = ""
    @State private var nameDraft: String = ""
    @State private var pickedWorkspaceURLs: [URL] = []
    @State private var pickedWorkspaceLabel: String = ""
    @State private var workspaceNameDraft: String = ""
    @State private var selectedIntegrations: Set<String> = []

    private let integrationChoices: [(id: String, label: String)] = [
        ("browser", "Browser"),
        ("vscode", "VS Code"),
        ("terminal", "Terminal"),
        ("github", "GitHub"),
        ("openclaw-gateway", "OpenClaw")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space20) {
            Text("New Dexter")
                .font(DexterTypography.display())
                .foregroundColor(DexterColors.textPrimary)

            Text("What should this Dexter help you with?")
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)

            TextField("Purpose", text: $purposeDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(DexterMetrics.space12)
                .background(DexterColors.inputBackground)
                .cornerRadius(DexterMetrics.radiusMedium)

            TextField("Name", text: $nameDraft)
                .textFieldStyle(.plain)
                .padding(DexterMetrics.space12)
                .background(DexterColors.inputBackground)
                .cornerRadius(DexterMetrics.radiusMedium)

            VStack(alignment: .leading, spacing: DexterMetrics.space8) {
                Text("Optional integrations")
                    .font(DexterTypography.section())
                    .foregroundColor(DexterColors.textTertiary)
                ForEach(integrationChoices, id: \.id) { choice in
                    Toggle(choice.label, isOn: bindingForIntegration(choice.id))
                        .toggleStyle(.checkbox)
                        .pointerCursor()
                }
            }

            VStack(alignment: .leading, spacing: DexterMetrics.space8) {
                Text("Optional workspace")
                    .font(DexterTypography.section())
                    .foregroundColor(DexterColors.textTertiary)
                Button("Choose folders or files…") {
                    let urls = companionManager.dexterFileWorkspaceService.pickWorkspaceURLs()
                    pickedWorkspaceURLs = urls
                    if let first = urls.first {
                        workspaceNameDraft = DexterFileWorkspaceBookmarkAccess.suggestedWorkspaceName(for: first)
                        pickedWorkspaceLabel = urls
                            .map { DexterFileWorkspaceBookmarkAccess.tildeDisplayPath(for: $0.path) }
                            .joined(separator: ", ")
                    }
                }
                .buttonStyle(.bordered)
                .pointerCursor()
                if !pickedWorkspaceLabel.isEmpty {
                    Text(pickedWorkspaceLabel)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                    TextField("Workspace name", text: $workspaceNameDraft)
                        .textFieldStyle(.plain)
                        .padding(DexterMetrics.space12)
                        .background(DexterColors.inputBackground)
                        .cornerRadius(DexterMetrics.radiusMedium)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .pointerCursor()
                Spacer()
                Button("Create") { createProfile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate)
                    .pointerCursor()
            }
        }
        .padding(DexterMetrics.space24)
        .frame(width: 440)
        .background(DexterColors.backgroundElevated)
    }

    private var canCreate: Bool {
        !purposeDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func bindingForIntegration(_ integrationId: String) -> Binding<Bool> {
        Binding(
            get: { selectedIntegrations.contains(integrationId) },
            set: { isOn in
                if isOn {
                    selectedIntegrations.insert(integrationId)
                } else {
                    selectedIntegrations.remove(integrationId)
                }
            }
        )
    }

    private func createProfile() {
        companionManager.createDexterProfileFromHome(
            name: nameDraft,
            purpose: purposeDraft,
            connectedIntegrations: Array(selectedIntegrations).sorted(),
            workspaceURLs: pickedWorkspaceURLs,
            workspaceName: workspaceNameDraft.isEmpty ? nil : workspaceNameDraft
        )
        dismiss()
    }
}
