//
//  DexterRoutineDetailView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterRoutineDetailView: View {
    @ObservedObject var companionManager: CompanionManager
    let routineId: UUID
    var onDismiss: () -> Void

    @State private var showsDeleteConfirmation = false
    @State private var isEditing = false

    private var routine: DexterRoutine? {
        companionManager.dexterRoutineStore.routine(withId: routineId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let routine {
                    detailContent(routine: routine)
                } else {
                    Text("Routine not found.")
                        .foregroundColor(DexterColors.textSecondary)
                }
            }
            .padding(DexterSpacing.lg)
            .background(DexterSurfaceColors.background)
            .navigationTitle("Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    @ViewBuilder
    private func detailContent(routine: DexterRoutine) -> some View {
        VStack(alignment: .leading, spacing: DexterSpacing.lg) {
            Text(routine.name)
                .font(DexterTypography.title())
                .foregroundColor(DexterSurfaceColors.textPrimary)

            infoBlock(title: "Status", value: routine.status.displayName)
            infoBlock(title: "Trigger", value: routine.trigger.summaryLabel)
            infoBlock(title: "Instruction", value: routine.instruction)

            if let profile = companionManager.dexterProfileStore.profile(withId: routine.dexterProfileId) {
                infoBlock(title: "Dexter", value: profile.name)
            }

            if let nextRunAt = routine.nextRunAt, routine.trigger.kind == .schedule {
                infoBlock(title: "Next run", value: formattedDate(nextRunAt))
            }
            if let lastRunAt = routine.lastRunAt {
                infoBlock(title: "Last run", value: formattedDate(lastRunAt))
            }
            if let failure = routine.lastFailureReason, routine.status == .failed {
                Text(failure)
                    .font(DexterTypography.caption())
                    .foregroundColor(.orange)
            }

            HStack(spacing: DexterSpacing.sm) {
                Button("Run now") {
                    companionManager.runDexterRoutine(routineID: routine.id, runKind: .manual)
                }
                .buttonStyle(.borderedProminent)
                .tint(DexterPastelColors.lavender)
                .pointerCursor()

                if routine.status == .paused {
                    Button("Resume") {
                        companionManager.dexterRoutineStore.setPaused(routineId: routine.id, isPaused: false)
                    }
                    .pointerCursor()
                } else {
                    Button("Pause") {
                        companionManager.dexterRoutineStore.setPaused(routineId: routine.id, isPaused: true)
                    }
                    .pointerCursor()
                }

                Button("Delete", role: .destructive) {
                    showsDeleteConfirmation = true
                }
                .pointerCursor()
            }

            if !routine.runHistory.isEmpty {
                Text("RUN HISTORY")
                    .font(DexterTypography.section())
                    .foregroundColor(DexterColors.textTertiary)
                ForEach(routine.runHistory) { record in
                    HStack {
                        Text(formattedDate(record.startedAt))
                        Spacer()
                        Text(record.succeeded ? "✓ Completed" : "✕ Failed")
                            .foregroundColor(record.succeeded ? DexterPastelColors.lavender : .orange)
                    }
                    .font(DexterTypography.caption())
                }
            }
        }
        .confirmationDialog(
            "Delete \(routine.name)?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                companionManager.dexterRoutineStore.deleteRoutine(id: routine.id)
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop future runs.")
        }
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
            Text(value)
                .font(DexterTypography.body())
                .foregroundColor(DexterSurfaceColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
