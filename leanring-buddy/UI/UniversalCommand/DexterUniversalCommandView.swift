//
//  DexterUniversalCommandView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterUniversalCommandView: View {
    @ObservedObject var panelState: DexterUniversalCommandPanelState
    @ObservedObject var companionManager: CompanionManager

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider().background(DexterColors.borderSubtle)
            resultsScrollView
            footerHints
        }
        .frame(width: 560, height: min(460, panelState.maxContentHeight))
        .background(DexterColors.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DexterMetrics.radiusLarge, style: .continuous)
                .stroke(DexterColors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Universal Command")
        .onAppear {
            panelState.refreshSections(companionManager: companionManager)
            DispatchQueue.main.async {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: panelState.query) { _, _ in
            panelState.refreshSections(companionManager: companionManager)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: DexterMetrics.space12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DexterColors.textTertiary)
            TextField("Search or ask Dexter…", text: $panelState.query)
                .textFieldStyle(.plain)
                .font(DexterTypography.body())
                .focused($isSearchFieldFocused)
                .accessibilityLabel("Search or ask Dexter")
            if !panelState.query.isEmpty {
                Button {
                    panelState.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DexterColors.textTertiary)
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.horizontal, DexterMetrics.space16)
        .padding(.vertical, DexterMetrics.space14)
    }

    private var resultsScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DexterMetrics.space16) {
                    if panelState.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("SEARCH OR COMMAND")
                            .font(DexterTypography.caption())
                            .foregroundColor(DexterColors.textTertiary)
                            .padding(.horizontal, DexterMetrics.space16)
                        Text("Search Dexter")
                            .font(DexterTypography.secondary())
                            .foregroundColor(DexterColors.textSecondary)
                            .padding(.horizontal, DexterMetrics.space16)
                    }

                    ForEach(panelState.sections) { section in
                        VStack(alignment: .leading, spacing: DexterMetrics.space8) {
                            Text(section.group.title)
                                .font(DexterTypography.caption())
                                .foregroundColor(DexterColors.textTertiary)
                                .padding(.horizontal, DexterMetrics.space16)

                            ForEach(section.results) { result in
                                let flatIndex = panelState.flatResults.firstIndex(where: { $0.id == result.id }) ?? 0
                                DexterUniversalCommandResultRow(
                                    result: result,
                                    profile: result.dexterProfileId.flatMap { companionManager.dexterProfileStore.profile(withId: $0) },
                                    isSelected: panelState.selectedFlatIndex == flatIndex,
                                    onSelect: { panelState.selectFlatIndex(flatIndex) },
                                    onPerformPrimary: { panelState.onPerformResult?(result, false) },
                                    onPerformSecondary: { panelState.onPerformResult?(result, true) }
                                )
                                .id(result.id)
                            }
                        }
                    }
                }
                .padding(.vertical, DexterMetrics.space12)
            }
            .onChange(of: panelState.selectedFlatIndex) { _, newIndex in
                guard let result = panelState.flatResults[safe: newIndex] else { return }
                proxy.scrollTo(result.id, anchor: .center)
            }
        }
    }

    private var footerHints: some View {
        HStack(spacing: DexterMetrics.space16) {
            Text("⌘K Universal Command")
            Text("↑↓ Navigate")
            Text("↩ Open")
            Text("Esc Close")
        }
        .font(DexterTypography.caption())
        .foregroundColor(DexterColors.textTertiary)
        .padding(.horizontal, DexterMetrics.space16)
        .padding(.vertical, DexterMetrics.space10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DexterColors.background.opacity(0.6))
    }
}

struct DexterUniversalCommandResultRow: View {
    let result: DexterCommandResult
    let profile: DexterProfile?
    let isSelected: Bool
    var onSelect: () -> Void
    var onPerformPrimary: () -> Void
    var onPerformSecondary: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DexterMetrics.space12) {
            leadingIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(result.isUnavailable ? DexterColors.textTertiary : DexterSurfaceColors.textPrimary)
                if let subtitle = result.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                        .lineLimit(2)
                }
                if let unavailableReason = result.unavailableReason {
                    Text(unavailableReason)
                        .font(DexterTypography.caption())
                        .foregroundColor(.orange)
                }
            }
            Spacer(minLength: 0)
            if let secondaryTitle = result.secondaryActionTitle {
                Button(secondaryTitle) {
                    onPerformSecondary()
                }
                .buttonStyle(.plain)
                .font(DexterTypography.caption())
                .foregroundColor(DexterPastelColors.lavender)
                .pointerCursor()
            }
        }
        .padding(.horizontal, DexterMetrics.space16)
        .padding(.vertical, DexterMetrics.space10)
        .background(isSelected ? DexterPastelColors.lavender.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
            onPerformPrimary()
        }
        .pointerCursor()
        .accessibilityLabel(result.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if result.kind == .dexter, let profile,
           let definition = DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID) {
            DexterCharacterView(
                definition: definition,
                appearance: profile.characterAppearance,
                size: .tiny,
                presentationMode: .avatar,
                profileNameForAccessibility: profile.name
            )
            .frame(width: 28, height: 28)
        } else if let systemImageName = result.systemImageName {
            Image(systemName: systemImageName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DexterColors.textSecondary)
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "sparkles")
                .foregroundColor(DexterPastelColors.lavender)
                .frame(width: 28, height: 28)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
