//
//  DexterRoutinesListSheet.swift
//  leanring-buddy
//

import SwiftUI

struct DexterRoutinesListSheet: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRoutineId: UUID?

    private var profileId: UUID? {
        companionManager.dexterProfileStore.activeProfileId
    }

    private var routines: [DexterRoutine] {
        guard let profileId else { return companionManager.dexterRoutineStore.routines }
        return companionManager.dexterRoutineStore.routines(forProfileId: profileId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DexterSpacing.sm) {
                    ForEach(routines) { routine in
                        let profile = companionManager.dexterProfileStore.profile(withId: routine.dexterProfileId)
                        DexterRoutineCard(
                            routine: routine,
                            profile: profile,
                            characterState: routine.status == .failed ? .error : .idle,
                            onToggleEnabled: { isEnabled in
                                companionManager.dexterRoutineStore.setEnabled(routineId: routine.id, isEnabled: isEnabled)
                            },
                            onOpenDetails: { selectedRoutineId = routine.id },
                            onRunNow: {
                                companionManager.runDexterRoutine(routineID: routine.id, runKind: .manual)
                            }
                        )
                    }
                }
                .padding(DexterSpacing.lg)
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 520)
        .sheet(isPresented: Binding(
            get: { selectedRoutineId != nil },
            set: { isPresented in
                if !isPresented { selectedRoutineId = nil }
            }
        )) {
            if let routineId = selectedRoutineId {
                DexterRoutineDetailView(
                    companionManager: companionManager,
                    routineId: routineId,
                    onDismiss: { selectedRoutineId = nil }
                )
            }
        }
    }
}
