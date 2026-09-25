//
//  DexterFileWorkspaceService.swift
//  leanring-buddy
//

import AppKit
import Foundation

@MainActor
final class DexterFileWorkspaceService {
    let store: DexterFileWorkspaceStore

    init(store: DexterFileWorkspaceStore) {
        self.store = store
    }

    func pickWorkspaceURLs() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Choose workspace folders or files"
        panel.message = "Select what this Dexter can access. Dexter will not scan the rest of your Mac."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    func addPickedURLs(
        profileId: UUID,
        profileName: String,
        urls: [URL],
        workspaceName: String
    ) {
        guard !urls.isEmpty else { return }

        let trimmedWorkspaceName = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        var workspace = store.workspace(forProfileId: profileId)
        if workspace == nil {
            workspace = DexterFileWorkspace(
                dexterProfileId: profileId,
                name: trimmedWorkspaceName.isEmpty ? profileName : trimmedWorkspaceName
            )
        }
        guard var workspace else { return }

        for url in urls {
            let standardized = url.standardizedFileURL
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory)
            let kind: DexterFileWorkspaceLocationKind = isDirectory.boolValue ? .folder : .file
            let location = DexterFileWorkspaceLocation(
                kind: kind,
                displayName: DexterFileWorkspaceBookmarkAccess.suggestedDisplayName(for: standardized),
                securityScopedBookmarkData: DexterFileWorkspaceBookmarkAccess.makeBookmarkData(for: standardized),
                lastResolvedPath: standardized.path,
                accessState: .available
            )
            workspace.locations.append(location)
        }

        workspace.indexStatus = .needsRefresh
        store.upsertWorkspace(workspace)
        store.refreshLocationAccessStates(forProfileId: profileId)
        store.scheduleIndexing(forProfileId: profileId, forceFull: false)
    }

    func removeLocation(profileId: UUID, locationId: UUID) {
        guard var workspace = store.workspace(forProfileId: profileId) else { return }
        workspace.locations.removeAll { $0.id == locationId }
        if workspace.locations.isEmpty {
            store.removeWorkspace(forProfileId: profileId)
        } else {
            workspace.indexStatus = .needsRefresh
            store.upsertWorkspace(workspace)
            store.scheduleIndexing(forProfileId: profileId, forceFull: true)
        }
    }

    func removeWorkspace(profileId: UUID) {
        store.removeWorkspace(forProfileId: profileId)
    }

    func openFile(_ fileContext: DexterFileContext) {
        NSWorkspace.shared.open(URL(fileURLWithPath: fileContext.absolutePath))
    }

    func revealInFinder(_ fileContext: DexterFileContext) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: fileContext.absolutePath)])
    }

    func revealLocationInFinder(profileId: UUID, locationId: UUID) {
        guard let workspace = store.workspace(forProfileId: profileId),
              let location = workspace.locations.first(where: { $0.id == locationId }),
              let resolved = DexterFileWorkspaceBookmarkAccess.resolve(location: location) else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([resolved.url])
        resolved.url.stopAccessingSecurityScopedResource()
    }

    func migrateAllLegacyProfileWorkspaces(profiles: [DexterProfile]) {
        for profile in profiles {
            store.migrateLegacyProfileWorkspaceIfNeeded(
                profileId: profile.id,
                legacyWorkspace: profile.workspace,
                suggestedName: profile.workspace.label ?? profile.name
            )
        }
    }
}
