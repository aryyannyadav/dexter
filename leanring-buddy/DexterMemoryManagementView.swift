//
//  DexterMemoryManagementView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMemoryManagementView: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var isExpanded = false

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
                sessionMemoryRow

                if let activeTaskDescription = companionManager.dexterActiveTaskDescription,
                   !activeTaskDescription.isEmpty {
                    memorySectionHeader("Active task")
                    memoryRow(
                        title: activeTaskDescription,
                        subtitle: "Workflow state",
                        onRemove: { companionManager.clearDexterActiveTask() }
                    )
                }

                if let workflowSummary = companionManager.dexterWorkflowContextSummary,
                   !workflowSummary.isEmpty {
                    memorySectionHeader("Workflow")
                    memoryRow(
                        title: workflowSummary,
                        subtitle: "Context",
                        onRemove: { companionManager.clearDexterWorkflowContext() }
                    )
                }

                if !companionManager.dexterPersistentMemoryEntries.isEmpty {
                    memorySectionHeader("Saved")
                    ForEach(companionManager.dexterPersistentMemoryEntries) { entry in
                        memoryRow(
                            title: entry.title,
                            subtitle: entry.content,
                            onRemove: { companionManager.removeDexterMemoryEntry(entry.id) }
                        )
                    }
                }

                if companionManager.dexterSessionExchangeCount == 0
                    && companionManager.dexterPersistentMemoryEntries.isEmpty
                    && companionManager.dexterActiveTaskDescription == nil
                    && companionManager.dexterWorkflowContextSummary == nil {
                    Text("No saved memory yet. Say “remember that …” or set a task explicitly.")
                        .font(DexterIdentity.Typography.body())
                        .foregroundColor(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                }
                }
            }
        }
    }

    private var memorySummaryLabel: String {
        let savedCount = companionManager.dexterPersistentMemoryEntries.count
        let sessionCount = companionManager.dexterSessionExchangeCount
        if savedCount == 0 && sessionCount == 0 {
            return "Empty"
        }
        return "\(savedCount) saved · \(sessionCount) session"
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

    private func memoryRow(title: String, subtitle: String, onRemove: @escaping () -> Void) -> some View {
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
}
