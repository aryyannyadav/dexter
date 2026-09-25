//
//  DexterProfileActivityView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterProfileActivityView: View {
    @ObservedObject var companionManager: CompanionManager
    let profileId: UUID?
    var showsDexterLabels: Bool

    @State private var selectedFilter: DexterActivityFilter = .all
    @State private var selectedActivity: DexterActivityRecord?

    private var profileName: String? {
        guard let profileId else { return nil }
        return companionManager.dexterProfileStore.profile(withId: profileId)?.name
    }

    private var filteredEvents: [DexterActivityRecord] {
        companionManager.dexterActivityRecorder.recentEvents(
            forProfileId: profileId,
            includeGlobal: profileId == nil,
            filter: selectedFilter,
            limit: 120
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space16) {
            if hasMultipleFilterOptions {
                filterBar
            }

            if filteredEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DexterMetrics.space20) {
                        ForEach(DexterActivityPresentation.groupedSections(from: filteredEvents), id: \.section.id) { group in
                            VStack(alignment: .leading, spacing: DexterMetrics.space10) {
                                Text(group.section.title)
                                    .font(DexterTypography.caption())
                                    .foregroundColor(DexterColors.textTertiary)

                                ForEach(group.events) { record in
                                    HStack(alignment: .top, spacing: DexterMetrics.space8) {
                                        Text(DexterActivityPresentation.timeLabel(for: record.timestamp))
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(DexterColors.textTertiary)
                                            .frame(width: 64, alignment: .leading)

                                        DexterActivityRow(
                                            record: record,
                                            dexterName: dexterName(for: record),
                                            showsDexterLabel: showsDexterLabels,
                                            onSelect: { selectedActivity = record }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, DexterMetrics.space4)
                }
            }
        }
        .sheet(item: $selectedActivity) { activity in
            DexterActivityDetailSheet(
                companionManager: companionManager,
                record: activity
            )
        }
    }

    private var hasMultipleFilterOptions: Bool {
        DexterActivityFilter.allCases.contains { filter in
            filter != .all
                && !companionManager.dexterActivityRecorder.recentEvents(
                    forProfileId: profileId,
                    includeGlobal: profileId == nil,
                    filter: filter,
                    limit: 1
                ).isEmpty
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DexterMetrics.space8) {
                ForEach(DexterActivityFilter.allCases) { filter in
                    let hasData = filter == .all || !companionManager.dexterActivityRecorder.recentEvents(
                        forProfileId: profileId,
                        includeGlobal: profileId == nil,
                        filter: filter,
                        limit: 1
                    ).isEmpty
                    if hasData {
                        Button(filter.title) {
                            selectedFilter = filter
                        }
                        .buttonStyle(.plain)
                        .font(DexterTypography.caption())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter
                                    ? DexterPastelColors.lavender.opacity(0.2)
                                    : DexterSurfaceColors.surface)
                        )
                        .foregroundColor(selectedFilter == filter ? DexterPastelColors.lavender : DexterColors.textSecondary)
                        .pointerCursor()
                        .accessibilityLabel("\(filter.title) filter")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DexterMetrics.space12) {
            if let profileId,
               let profile = companionManager.dexterProfileStore.profile(withId: profileId),
               let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
                DexterCharacterView(
                    definition: definition,
                    appearance: profile.characterAppearance,
                    size: .small,
                    presentationMode: .full,
                    profileNameForAccessibility: profile.name
                )
                .frame(height: 120)
            }

            Text("No activity yet.")
                .font(DexterTypography.title())
                .foregroundColor(DexterSurfaceColors.textPrimary)
            Text("Once Dexter starts helping you, you'll see meaningful actions and results here.")
                .font(DexterTypography.secondary())
                .foregroundColor(DexterColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DexterMetrics.space24)
    }

    private func dexterName(for record: DexterActivityRecord) -> String? {
        guard let profileId = record.dexterProfileId else { return "All Dexters" }
        return companionManager.dexterProfileStore.profile(withId: profileId)?.name
    }
}
