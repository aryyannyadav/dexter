//
//  DexterHomeRecentActivitySection.swift
//  leanring-buddy
//

import SwiftUI

struct DexterHomeRecentActivitySection: View {
    @ObservedObject var companionManager: CompanionManager
    var profileId: UUID?
    var onViewAll: () -> Void

    private var recentEvents: [DexterActivityRecord] {
        companionManager.dexterActivityRecorder.recentEvents(
            forProfileId: profileId,
            includeGlobal: true,
            limit: 3
        )
    }

    var body: some View {
        if !recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: DexterSpacing.md) {
                HStack {
                    Text("Recent activity")
                        .font(DexterTypography.cardTitle())
                        .foregroundColor(DexterColors.textPrimary)
                    Spacer(minLength: 0)
                    Button("View all", action: onViewAll)
                        .buttonStyle(.plain)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterPastelColors.lavender)
                        .pointerCursor()
                }

                ForEach(recentEvents) { record in
                    DexterActivityRow(
                        record: record,
                        dexterName: dexterName(for: record),
                        showsDexterLabel: profileId == nil
                    )
                }
            }
        }
    }

    private func dexterName(for record: DexterActivityRecord) -> String? {
        guard let profileId = record.dexterProfileId else { return nil }
        return companionManager.dexterProfileStore.profile(withId: profileId)?.name
    }
}
