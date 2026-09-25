//
//  DexterMyDextersSettingsPage.swift
//  leanring-buddy
//

import SwiftUI

struct DexterMyDextersSettingsPage: View {
    @ObservedObject var companionManager: CompanionManager

    private var profileStore: DexterProfileStore {
        companionManager.dexterProfileStore
    }

    var body: some View {
        DexterSettingsPageContainer(
            title: "My Dexters",
            subtitle: "Profiles share one settings store — switch the active Dexter from Home or Profile."
        ) {
            DexterSettingsSection(title: "Profiles") {
                ForEach(profileStore.profiles) { profile in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: profile.avatar.symbolName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(profile.accentColor)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(DexterSettingsTypography.rowTitle())
                                .foregroundColor(DS.Colors.textPrimary)
                            Text(profile.purpose.isEmpty ? profile.description : profile.purpose)
                                .font(DexterSettingsTypography.rowSubtitle())
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if profile.id == profileStore.activeProfileId {
                            Text("Active")
                                .font(DexterSettingsTypography.secondaryValue())
                                .foregroundColor(DexterPastelColors.lavender)
                        } else {
                            DexterSettingsSecondaryButton(title: "Activate") {
                                profileStore.setActiveProfile(id: profile.id)
                            }
                        }
                    }
                    .padding(.vertical, 6)

                    if profile.id != profileStore.profiles.last?.id {
                        DexterSettingsDivider()
                    }
                }
            }

            DexterSettingsSecondaryButton(title: "Open Dexter Home") {
                NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            }
            .padding(.top, 4)
        }
    }
}
