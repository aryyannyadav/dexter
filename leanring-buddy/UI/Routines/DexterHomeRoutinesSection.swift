//
//  DexterHomeRoutinesSection.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeRoutinesSection: View {
    @ObservedObject var companionManager: CompanionManager
    var onViewAll: () -> Void
    var onCreateRoutine: () -> Void
    var onOpenRoutine: (UUID) -> Void

    private var activeProfileId: UUID? {
        companionManager.dexterProfileStore.activeProfileId
    }

    private var displayedRoutines: [DexterRoutine] {
        guard let profileId = activeProfileId else { return [] }
        return companionManager.dexterRoutineStore
            .activeRoutines(forProfileId: profileId)
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        if displayedRoutines.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                HStack {
                    Text("Your routines")
                        .font(DexterTypography.section())
                        .foregroundColor(DexterColors.textTertiary)
                    Spacer()
                    Button("View all", action: onViewAll)
                        .font(DexterTypography.caption())
                        .buttonStyle(.plain)
                        .foregroundColor(DexterPastelColors.lavender)
                        .pointerCursor()
                }

                ForEach(displayedRoutines) { routine in
                    let profile = companionManager.dexterProfileStore.profile(withId: routine.dexterProfileId)
                    DexterRoutineCard(
                        routine: routine,
                        profile: profile,
                        characterState: routine.status == .failed ? .error : .idle,
                        onToggleEnabled: { isEnabled in
                            companionManager.dexterRoutineStore.setEnabled(routineId: routine.id, isEnabled: isEnabled)
                        },
                        onOpenDetails: { onOpenRoutine(routine.id) },
                        onRunNow: {
                            companionManager.runDexterRoutine(routineID: routine.id, runKind: .manual)
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        Button(action: onCreateRoutine) {
            Label("Create routine", systemImage: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DexterColors.textSecondary)
                .padding(.horizontal, DexterSpacing.md)
                .padding(.vertical, DexterSpacing.sm)
                .background(
                    Capsule(style: .continuous)
                        .fill(DexterSurfaceColors.surfaceElevated.opacity(0.92))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DexterSurfaceColors.border.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .accessibilityLabel("Create routine")
    }
}
