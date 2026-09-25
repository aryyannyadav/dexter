//
//  DexterMemorySettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMemorySettingsPage: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var showsClearMemoryConfirmation = false

    var body: some View {
        DexterSettingsPageContainer(
            title: "Memory",
            subtitle: "Saved facts and session memory Dexter can recall."
        ) {
            DexterSettingsSection(title: "Overview") {
                DexterSettingsInfoRow(
                    title: "Saved memories",
                    value: "\(companionManager.dexterPersistentMemoryEntries.count)"
                )
                DexterSettingsDivider()
                DexterSettingsInfoRow(
                    title: "Session exchanges",
                    value: "\(companionManager.dexterSessionExchangeCount)"
                )
            }

            DexterSettingsSection(title: "Manage") {
                DexterSettingsSecondaryButton(title: "Open memory manager") {
                    companionManager.reloadDexterMemoryPresentation()
                    NotificationCenter.default.post(
                        name: .dexterOpenMainWindow,
                        object: nil
                    )
                }
                .padding(.bottom, 4)

                Text("View and remove individual memories from Home or the profile sheet.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
            }

            DexterSettingsSection(title: "Clear") {
                DexterSettingsSecondaryButton(title: "Clear Dexter memories") {
                    showsClearMemoryConfirmation = true
                }

                Text("Removes saved Dexter memories and revokes proactive automation preferences. Does not delete chat history.")
                    .font(DexterSettingsTypography.rowSubtitle())
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.top, 4)
            }
        }
        .confirmationDialog(
            "Clear Dexter memories?",
            isPresented: $showsClearMemoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear memories", role: .destructive) {
                companionManager.clearDexterMemoryAndTrustPreferences()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved memories and automation preferences. Your conversations stay in the current session until you start a new chat.")
        }
        .onAppear {
            companionManager.reloadDexterMemoryPresentation()
        }
    }
}
