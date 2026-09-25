//
//  DexterProfileFileWorkspaceViews.swift
//  leanring-buddy
//

import SwiftUI

struct DexterProfileFileWorkspaceSection: View {
    @ObservedObject var companionManager: CompanionManager
    let profile: DexterProfile

    @State private var isManagePresented = false
    @State private var isAddPresented = false
    @State private var isRemoveConfirmPresented = false
    @State private var previewFile: DexterFileContext?

    private var workspace: DexterFileWorkspace? {
        companionManager.dexterFileWorkspaceStore.workspace(forProfileId: profile.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.sm) {
            Text("WORKSPACE")
                .font(DexterTypography.section())
                .foregroundColor(DexterColors.textTertiary)

            if let workspace, workspace.hasAnyLocation {
                connectedWorkspaceContent(workspace: workspace)
            } else {
                Text("No workspace connected.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                Button("Add workspace") {
                    isAddPresented = true
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(profile.accentColor)
                .pointerCursor()
                .accessibilityLabel("Add workspace")
            }
        }
        .onAppear {
            companionManager.dexterFileWorkspaceStore.refreshLocationAccessStates(forProfileId: profile.id)
        }
        .sheet(isPresented: $isManagePresented) {
            DexterProfileFileWorkspaceManageSheet(
                companionManager: companionManager,
                profile: profile,
                onDismiss: { isManagePresented = false }
            )
        }
        .sheet(isPresented: $isAddPresented) {
            DexterProfileFileWorkspaceAddSheet(
                companionManager: companionManager,
                profile: profile,
                onDismiss: { isAddPresented = false }
            )
        }
        .sheet(item: $previewFile) { file in
            DexterProfileFileWorkspacePreviewSheet(
                file: file,
                accentColor: profile.accentColor,
                onOpen: { companionManager.dexterFileWorkspaceService.openFile(file) },
                onReveal: { companionManager.dexterFileWorkspaceService.revealInFinder(file) },
                onDismiss: { previewFile = nil }
            )
        }
        .alert("Remove this workspace from \(profile.name)?", isPresented: $isRemoveConfirmPresented) {
            Button("Remove", role: .destructive) {
                companionManager.dexterFileWorkspaceService.removeWorkspace(profileId: profile.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This won't delete your files.")
        }
    }

    @ViewBuilder
    private func connectedWorkspaceContent(workspace: DexterFileWorkspace) -> some View {
        Text(workspace.name)
            .font(DexterTypography.title())
            .foregroundColor(DexterSurfaceColors.textPrimary)

        if let primaryPath = workspace.locations.first?.lastResolvedPath {
            Text(DexterFileWorkspaceBookmarkAccess.tildeDisplayPath(for: primaryPath))
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
        }

        if workspace.indexStatus == .ready,
           let fileCount = workspace.indexedFileCount,
           let folderCount = workspace.indexedFolderCount {
            Text("\(folderCount) folders · \(fileCount) files")
                .font(DexterTypography.secondary())
                .foregroundColor(DexterColors.textSecondary)
        } else if workspace.indexStatus == .indexing, let progress = workspace.indexProgress {
            Text("Indexing \(workspace.name)… \(Int(progress * 100))%")
                .font(DexterTypography.secondary())
                .foregroundColor(DexterColors.textSecondary)
        }

        if let git = workspace.gitSummary, git.isGitRepository {
            HStack(spacing: DexterSpacing.xs) {
                Text("Git repository")
                if let branch = git.branchName {
                    Text("Branch: \(branch)")
                }
                if let status = git.shortStatusSummary {
                    Text("Status: \(status)")
                }
            }
            .font(DexterTypography.caption())
            .foregroundColor(DexterColors.textTertiary)
        }

        if let lastIndexed = workspace.lastIndexedAt, workspace.indexStatus == .ready {
            Text("Last scanned: \(lastIndexed.formatted(date: .abbreviated, time: .omitted))")
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
        }

        HStack(spacing: DexterSpacing.md) {
            Button("Open workspace") {
                if let locationId = workspace.locations.first?.id {
                    companionManager.dexterFileWorkspaceService.revealLocationInFinder(
                        profileId: profile.id,
                        locationId: locationId
                    )
                }
            }
            .buttonStyle(.plain)
            .font(DexterTypography.bodyMedium())
            .foregroundColor(profile.accentColor)
            .pointerCursor()

            Button("Manage") {
                isManagePresented = true
            }
            .buttonStyle(.plain)
            .font(DexterTypography.bodyMedium())
            .foregroundColor(profile.accentColor)
            .pointerCursor()

            Button("Add location") {
                isAddPresented = true
            }
            .buttonStyle(.plain)
            .font(DexterTypography.bodyMedium())
            .foregroundColor(profile.accentColor)
            .pointerCursor()
        }

        let recent = companionManager.dexterFileWorkspaceStore.recentFiles(forProfileId: profile.id, limit: 3)
        if !recent.isEmpty {
            Text("RECENT FILES")
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
                .padding(.top, DexterSpacing.xs)
            ForEach(recent) { file in
                Button {
                    previewFile = file
                } label: {
                    HStack {
                        Text(file.name)
                            .font(DexterTypography.bodyMedium())
                            .foregroundColor(DexterSurfaceColors.textPrimary)
                        Spacer()
                        if let modifiedAt = file.modifiedAt {
                            Text(relativeDate(modifiedAt))
                                .font(DexterTypography.caption())
                                .foregroundColor(DexterColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .accessibilityLabel("\(file.name), \(file.contentKind.userFacingLabel) file")
            }
        }

        Button("Remove workspace") {
            isRemoveConfirmPresented = true
        }
        .buttonStyle(.plain)
        .font(DexterTypography.caption())
        .foregroundColor(DexterColors.textTertiary)
        .pointerCursor()
        .padding(.top, DexterSpacing.xs)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DexterProfileFileWorkspaceAddSheet: View {
    @ObservedObject var companionManager: CompanionManager
    let profile: DexterProfile
    var onDismiss: () -> Void

    @State private var workspaceName: String = ""
    @State private var pickedURLs: [URL] = []
    @State private var pickedPathLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.lg) {
            Text("Add workspace")
                .font(DexterTypography.title())
            Text("Choose folders or files Dexter can use for this profile.")
                .font(DexterTypography.secondary())
                .foregroundColor(DexterColors.textSecondary)

            Button("Choose folders or files…") {
                let urls = companionManager.dexterFileWorkspaceService.pickWorkspaceURLs()
                pickedURLs = urls
                if let first = urls.first {
                    workspaceName = DexterFileWorkspaceBookmarkAccess.suggestedWorkspaceName(for: first)
                    pickedPathLabel = urls.map { DexterFileWorkspaceBookmarkAccess.tildeDisplayPath(for: $0.path) }.joined(separator: ", ")
                }
            }
            .buttonStyle(.bordered)
            .pointerCursor()

            if !pickedPathLabel.isEmpty {
                Text("Location: \(pickedPathLabel)")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }

            TextField("Workspace name", text: $workspaceName)
                .textFieldStyle(.plain)
                .padding(DexterSpacing.sm)
                .background(DexterColors.inputBackground)
                .cornerRadius(DexterMetrics.radiusMedium)

            HStack {
                Button("Cancel", action: onDismiss)
                    .pointerCursor()
                Spacer()
                Button("Add") {
                    companionManager.dexterFileWorkspaceService.addPickedURLs(
                        profileId: profile.id,
                        profileName: profile.name,
                        urls: pickedURLs,
                        workspaceName: workspaceName
                    )
                    onDismiss()
                }
                .disabled(pickedURLs.isEmpty)
                .buttonStyle(.borderedProminent)
                .pointerCursor()
            }
        }
        .padding(DexterSpacing.lg)
        .frame(width: 440)
    }
}

struct DexterProfileFileWorkspaceManageSheet: View {
    @ObservedObject var companionManager: CompanionManager
    let profile: DexterProfile
    var onDismiss: () -> Void

    private var workspace: DexterFileWorkspace? {
        companionManager.dexterFileWorkspaceStore.workspace(forProfileId: profile.id)
    }

    var body: some View {
        NavigationStack {
            List {
                if let workspace {
                    Section("Workspace locations") {
                        ForEach(workspace.locations) { location in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(location.displayName)
                                        .font(DexterTypography.bodyMedium())
                                    if let path = location.lastResolvedPath {
                                        Text(DexterFileWorkspaceBookmarkAccess.tildeDisplayPath(for: path))
                                            .font(DexterTypography.caption())
                                            .foregroundColor(DexterColors.textTertiary)
                                    }
                                    Text(accessLabel(for: location.accessState))
                                        .font(DexterTypography.caption())
                                        .foregroundColor(accessColor(for: location.accessState))
                                }
                                Spacer()
                                if location.accessState == .permissionRequired || location.accessState == .stale {
                                    Button("Choose again") {
                                        let urls = companionManager.dexterFileWorkspaceService.pickWorkspaceURLs()
                                        if let url = urls.first {
                                            companionManager.dexterFileWorkspaceService.removeLocation(
                                                profileId: profile.id,
                                                locationId: location.id
                                            )
                                            companionManager.dexterFileWorkspaceService.addPickedURLs(
                                                profileId: profile.id,
                                                profileName: profile.name,
                                                urls: [url],
                                                workspaceName: workspace.name
                                            )
                                        }
                                    }
                                    .pointerCursor()
                                } else {
                                    Button("Reveal") {
                                        companionManager.dexterFileWorkspaceService.revealLocationInFinder(
                                            profileId: profile.id,
                                            locationId: location.id
                                        )
                                    }
                                    .pointerCursor()
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let locationId = workspace.locations[index].id
                                companionManager.dexterFileWorkspaceService.removeLocation(
                                    profileId: profile.id,
                                    locationId: locationId
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage workspace")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private func accessLabel(for state: DexterFileWorkspaceAccessState) -> String {
        switch state {
        case .available: return "Available"
        case .permissionRequired: return "Permission required"
        case .missing: return "Missing"
        case .stale: return "Stale bookmark"
        case .unavailable: return "Unavailable"
        }
    }

    private func accessColor(for state: DexterFileWorkspaceAccessState) -> Color {
        switch state {
        case .available: return DexterColors.textSecondary
        case .permissionRequired, .stale, .missing: return .orange
        case .unavailable: return DexterColors.textTertiary
        }
    }
}

struct DexterProfileFileWorkspacePreviewSheet: View {
    let file: DexterFileContext
    let accentColor: Color
    var onOpen: () -> Void
    var onReveal: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            Text(file.name)
                .font(DexterTypography.title())
            Text("\(file.contentKind.userFacingLabel) · \(file.displayPath)")
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
            if let byteSize = file.byteSize {
                Text(ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file))
                    .font(DexterTypography.secondary())
            }
            if let modifiedAt = file.modifiedAt {
                Text("Modified \(modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(DexterTypography.secondary())
            }
            if let snippet = file.searchableTextSnippet, !snippet.isEmpty {
                ScrollView {
                    Text(String(snippet.prefix(4_000)))
                        .font(DexterTypography.monospacedCaption())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }
            HStack {
                Button("Open", action: onOpen)
                    .pointerCursor()
                Button("Reveal in Finder", action: onReveal)
                    .pointerCursor()
                Spacer()
                Button("Done", action: onDismiss)
                    .pointerCursor()
            }
        }
        .padding(DexterSpacing.lg)
        .frame(width: 480)
    }
}
