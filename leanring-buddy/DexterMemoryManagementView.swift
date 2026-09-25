//
//  DexterMemoryManagementView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMemoryManagementView: View {
    @ObservedObject var companionManager: CompanionManager
    /// When set, shows memories for this Dexter profile (including global). When nil, uses the active profile.
    var scopedProfileId: UUID? = nil

    @State private var isExpanded = false
    @State private var memoryPendingForget: DexterStructuredMemoryRecord?
    @State private var memoryBeingEdited: DexterStructuredMemoryRecord?
    @State private var editedMemoryText = ""
    @State private var isClearDexterMemoryAlertPresented = false

    private var effectiveProfileId: UUID? {
        scopedProfileId ?? companionManager.dexterProfileStore.activeProfileId
    }

    private var profileDisplayName: String {
        guard let effectiveProfileId,
              let profile = companionManager.dexterProfileStore.profile(withId: effectiveProfileId) else {
            return "Dexter"
        }
        return profile.name
    }

    private var structuredMemories: [DexterStructuredMemoryRecord] {
        guard let effectiveProfileId else { return [] }
        return companionManager.structuredMemories(forProfileId: effectiveProfileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                isExpanded.toggle()
                if isExpanded {
                    companionManager.reloadDexterMemoryPresentation()
                }
            }) {
                HStack {
                    Text("MEMORY")
                        .font(DexterIdentity.Typography.sectionLabel())
                        .foregroundColor(DS.Colors.textTertiary)

                    Spacer()

                    Text(memorySummaryLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .pointerCursor()

            if isExpanded {
                DexterPanelCard {
                    VStack(alignment: .leading, spacing: 8) {
                        if let effectiveProfileId {
                            Text("\(profileDisplayName) remembers…")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DS.Colors.textSecondary)
                        }

                        sessionMemoryRow

                        if let activeTaskDescription = companionManager.dexterActiveTaskDescription,
                           !activeTaskDescription.isEmpty {
                            memorySectionHeader("Active task")
                            legacyMemoryRow(
                                title: activeTaskDescription,
                                subtitle: "Workflow state",
                                onRemove: { companionManager.clearDexterActiveTask() }
                            )
                        }

                        if let workflowSummary = companionManager.dexterWorkflowContextSummary,
                           !workflowSummary.isEmpty {
                            memorySectionHeader("Workflow")
                            legacyMemoryRow(
                                title: workflowSummary,
                                subtitle: "Context",
                                onRemove: { companionManager.clearDexterWorkflowContext() }
                            )
                        }

                        if structuredMemories.isEmpty {
                            emptySavedMemoriesState
                        } else {
                            ForEach(DexterMemoryProfileGroup.allCases) { group in
                                let memoriesInGroup = structuredMemories.filter { $0.profileGroup == group }
                                if !memoriesInGroup.isEmpty {
                                    memorySectionHeader(group.title)
                                    ForEach(memoriesInGroup) { memory in
                                        structuredMemoryRow(memory: memory)
                                    }
                                }
                            }
                        }

                        if effectiveProfileId != nil, !structuredMemories.isEmpty {
                            Button("Clear \(profileDisplayName) memory") {
                                isClearDexterMemoryAlertPresented = true
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .buttonStyle(.plain)
                            .pointerCursor()
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .alert("Forget this memory?", isPresented: Binding(
            get: { memoryPendingForget != nil },
            set: { if !$0 { memoryPendingForget = nil } }
        )) {
            Button("Forget", role: .destructive) {
                if let memoryPendingForget {
                    companionManager.removeDexterMemoryEntry(memoryPendingForget.id)
                }
                memoryPendingForget = nil
            }
            Button("Cancel", role: .cancel) {
                memoryPendingForget = nil
            }
        } message: {
            if let memoryPendingForget {
                Text(memoryPendingForget.userFacingSummary)
            }
        }
        .alert("Clear Dexter memory?", isPresented: $isClearDexterMemoryAlertPresented) {
            Button("Clear", role: .destructive) {
                if let effectiveProfileId {
                    companionManager.clearDexterScopedMemory(forProfileId: effectiveProfileId)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes saved memories scoped to \(profileDisplayName). Global memories and conversation history are not deleted.")
        }
        .sheet(item: $memoryBeingEdited) { memory in
            memoryEditSheet(memory: memory)
        }
    }

    private var emptySavedMemoriesState: some View {
        VStack(alignment: .leading, spacing: 4) {
            if companionManager.dexterActiveTaskDescription == nil
                && companionManager.dexterWorkflowContextSummary == nil {
                Text("No saved memories yet.")
                    .font(DexterIdentity.Typography.body())
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Tell Dexter something you'd like it to remember.")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var memorySummaryLabel: String {
        let savedCount = structuredMemories.count
        let sessionCount = companionManager.dexterSessionExchangeCount
        if savedCount == 0 && sessionCount == 0 {
            return "Empty"
        }
        if savedCount == 0 {
            return "\(sessionCount) session"
        }
        return "\(savedCount) saved"
    }

    private var sessionMemoryRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Session conversation")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                Text("\(companionManager.dexterSessionExchangeCount) exchanges this launch")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
            }

            Spacer()

            if companionManager.dexterSessionExchangeCount > 0 {
                Button("Clear") {
                    companionManager.clearDexterSessionMemory()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 4)
    }

    private func memorySectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundColor(DS.Colors.textTertiary)
            .padding(.top, 4)
    }

    private func structuredMemoryRow(memory: DexterStructuredMemoryRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.userFacingSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(memory.scopeLabel)
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textTertiary)
                    if DexterDeveloperModeSettings.isDeveloperModeEnabled {
                        Text("· \(memory.source.rawValue) · \(Int(memory.confidence * 100))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(DS.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                Button("Edit") {
                    memoryBeingEdited = memory
                    editedMemoryText = memory.content
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .buttonStyle(.plain)
                .pointerCursor()

                Button(action: { memoryPendingForget = memory }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 4)
    }

    private func legacyMemoryRow(title: String, subtitle: String, onRemove: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
                    .lineLimit(3)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
        .padding(.vertical, 4)
    }

    private func memoryEditSheet(memory: DexterStructuredMemoryRecord) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $editedMemoryText)
                    .font(.system(size: 13))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(DS.Colors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Edit memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { memoryBeingEdited = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        companionManager.updateDexterMemoryEntryContent(
                            memoryId: memory.id,
                            newContent: editedMemoryText
                        )
                        memoryBeingEdited = nil
                    }
                    .disabled(editedMemoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
    }
}
