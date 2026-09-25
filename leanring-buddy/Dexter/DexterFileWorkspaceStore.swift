//
//  DexterFileWorkspaceStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterFileWorkspaceStore: ObservableObject {
    weak var activityRecorder: DexterActivityRecorder?

    @Published private(set) var workspaces: [DexterFileWorkspace] = []
    @Published private(set) var indexSnapshots: [UUID: DexterFileWorkspaceIndexSnapshot] = [:]

    private let workspacesFileURL: URL
    private let indexDirectoryURL: URL
    private var indexingTasks: [UUID: Task<Void, Never>] = [:]

    init(workspacesFileURL: URL? = nil) {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dexterDirectory = supportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        self.workspacesFileURL = workspacesFileURL ?? dexterDirectory.appendingPathComponent("dexter-file-workspaces.json")
        self.indexDirectoryURL = dexterDirectory.appendingPathComponent("FileWorkspaceIndexes", isDirectory: true)
        loadFromDisk()
    }

    func workspace(forProfileId: UUID) -> DexterFileWorkspace? {
        workspaces.first { $0.dexterProfileId == forProfileId }
    }

    func indexSnapshot(forWorkspaceId workspaceId: UUID) -> DexterFileWorkspaceIndexSnapshot? {
        indexSnapshots[workspaceId]
    }

    func recentFiles(forProfileId: UUID, limit: Int = 5) -> [DexterFileContext] {
        guard let workspace = workspace(forProfileId: forProfileId),
              let snapshot = indexSnapshots[workspace.id] else {
            return []
        }
        return snapshot.files
            .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    func upsertWorkspace(_ workspace: DexterFileWorkspace) {
        var updated = workspace
        updated.updatedAt = Date()
        let isNewWorkspace = !workspaces.contains(where: { $0.dexterProfileId == workspace.dexterProfileId })
        if let index = workspaces.firstIndex(where: { $0.dexterProfileId == workspace.dexterProfileId }) {
            workspaces[index] = updated
        } else {
            workspaces.append(updated)
        }
        persistWorkspaces()
        if isNewWorkspace {
            activityRecorder?.recordWorkspaceAdded(workspace: updated)
        }
    }

    func removeWorkspace(forProfileId: UUID) {
        guard let workspace = workspace(forProfileId: forProfileId) else { return }
        indexingTasks[workspace.id]?.cancel()
        indexingTasks[workspace.id] = nil
        workspaces.removeAll { $0.dexterProfileId == forProfileId }
        indexSnapshots[workspace.id] = nil
        try? FileManager.default.removeItem(at: indexFileURL(for: workspace.id))
        persistWorkspaces()
        activityRecorder?.recordWorkspaceRemoved(
            workspaceName: workspace.name,
            workspaceId: workspace.id,
            dexterProfileId: forProfileId
        )
    }

    func refreshLocationAccessStates(forProfileId: UUID) {
        guard var workspace = workspace(forProfileId: forProfileId) else { return }
        var didChange = false
        for locationIndex in workspace.locations.indices {
            var location = workspace.locations[locationIndex]
            guard let resolved = DexterFileWorkspaceBookmarkAccess.resolve(location: location) else {
                location.accessState = .unavailable
                workspace.locations[locationIndex] = location
                didChange = true
                continue
            }
            location.lastResolvedPath = resolved.url.standardizedFileURL.path
            location.accessState = resolved.accessState
            if let refreshedBookmark = resolved.refreshedBookmarkData {
                location.securityScopedBookmarkData = refreshedBookmark
            }
            workspace.locations[locationIndex] = location
            resolved.url.stopAccessingSecurityScopedResource()
            didChange = true
        }
        if didChange {
            upsertWorkspace(workspace)
        }
    }

    func scheduleIndexing(forProfileId: UUID, forceFull: Bool = false) {
        guard let workspace = workspace(forProfileId: forProfileId), workspace.hasAnyLocation else { return }
        if workspaces.first(where: { $0.dexterProfileId == forProfileId })?.indexStatus == .indexing {
            return
        }

        indexingTasks[workspace.id]?.cancel()
        var indexingWorkspace = workspace
        indexingWorkspace.indexStatus = .indexing
        indexingWorkspace.indexProgress = 0
        indexingWorkspace.lastIndexErrorMessage = nil
        upsertWorkspace(indexingWorkspace)

        let workspaceId = workspace.id
        let profileIdForTask = forProfileId
        let previousSnapshot = forceFull ? nil : indexSnapshots[workspaceId]

        indexingTasks[workspaceId] = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let resolvedPairs = await self.resolveAllLocations(forProfileId: profileIdForTask)
            let capturedWorkspace = await self.workspace(forProfileId: profileIdForTask) ?? workspace

            if resolvedPairs.isEmpty {
                await MainActor.run {
                    if var failed = self.workspace(forProfileId: profileIdForTask) {
                        failed.indexStatus = .error
                        failed.indexProgress = nil
                        failed.lastIndexErrorMessage = "No accessible workspace locations."
                        self.upsertWorkspace(failed)
                    }
                    self.indexingTasks[workspaceId] = nil
                }
                return
            }

            let result = DexterFileWorkspaceIndexer.indexWorkspace(
                workspace: capturedWorkspace,
                resolvedLocations: resolvedPairs,
                previousSnapshot: previousSnapshot,
                onProgress: { update in
                    Task { @MainActor in
                        self.applyIndexProgress(workspaceId: workspaceId, update: update)
                    }
                }
            )

            await MainActor.run {
                self.indexSnapshots[workspaceId] = result.snapshot
                self.persistIndexSnapshot(result.snapshot)
                if var finished = self.workspace(forProfileId: profileIdForTask) {
                    finished.indexStatus = .ready
                    finished.indexProgress = 1
                    finished.lastIndexedAt = Date()
                    finished.indexedFolderCount = result.folderCount
                    finished.indexedFileCount = result.fileCount
                    finished.gitSummary = result.gitSummary
                    self.upsertWorkspace(finished)
                }
                self.indexingTasks[workspaceId] = nil
            }
        }
    }

    func migrateLegacyProfileWorkspaceIfNeeded(
        profileId: UUID,
        legacyWorkspace: DexterProfileWorkspace,
        suggestedName: String
    ) {
        guard workspace(forProfileId: profileId) == nil else { return }
        guard let folderPath = legacyWorkspace.folderPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !folderPath.isEmpty else {
            return
        }
        let expandedPath = NSString(string: folderPath).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let displayName = legacyWorkspace.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? legacyWorkspace.label!
            : DexterFileWorkspaceBookmarkAccess.suggestedDisplayName(for: url)
        let location = DexterFileWorkspaceLocation(
            kind: .folder,
            displayName: displayName,
            securityScopedBookmarkData: DexterFileWorkspaceBookmarkAccess.makeBookmarkData(for: url),
            lastResolvedPath: url.standardizedFileURL.path,
            accessState: .available
        )
        let workspace = DexterFileWorkspace(
            dexterProfileId: profileId,
            name: suggestedName,
            locations: [location],
            indexStatus: .notIndexed
        )
        upsertWorkspace(workspace)
        scheduleIndexing(forProfileId: profileId)
    }

    private func applyIndexProgress(workspaceId: UUID, update: DexterFileWorkspaceIndexer.IndexProgressUpdate) {
        guard let profileId = workspaces.first(where: { $0.id == workspaceId })?.dexterProfileId else { return }
        guard var workspace = workspace(forProfileId: profileId) else { return }
        workspace.indexProgress = update.progress
        if let partial = update.partialSnapshot {
            indexSnapshots[workspaceId] = partial
        }
        upsertWorkspace(workspace)
    }

    private func resolveAllLocations(forProfileId: UUID) async -> [(location: DexterFileWorkspaceLocation, url: URL)] {
        await MainActor.run {
            refreshLocationAccessStates(forProfileId: forProfileId)
            guard let workspace = workspace(forProfileId: forProfileId) else { return [] }
            var pairs: [(DexterFileWorkspaceLocation, URL)] = []
            for location in workspace.locations {
                guard let resolved = DexterFileWorkspaceBookmarkAccess.resolve(location: location),
                      resolved.accessState == .available || resolved.accessState == .stale else {
                    continue
                }
                pairs.append((location, resolved.url))
                resolved.url.stopAccessingSecurityScopedResource()
            }
            return pairs
        }
    }

    private func loadFromDisk() {
        let fileManager = FileManager.default
        let directory = workspacesFileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: indexDirectoryURL.path) {
            try? fileManager.createDirectory(at: indexDirectoryURL, withIntermediateDirectories: true)
        }

        if let data = try? Data(contentsOf: workspacesFileURL),
           let decoded = try? JSONDecoder().decode([DexterFileWorkspace].self, from: data) {
            workspaces = decoded
        }

        for workspace in workspaces {
            let indexURL = indexFileURL(for: workspace.id)
            if let data = try? Data(contentsOf: indexURL),
               let snapshot = try? JSONDecoder().decode(DexterFileWorkspaceIndexSnapshot.self, from: data) {
                indexSnapshots[workspace.id] = snapshot
            }
        }
    }

    private func persistWorkspaces() {
        let directory = workspacesFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(workspaces) {
            try? data.write(to: workspacesFileURL, options: [.atomic])
        }
    }

    private func persistIndexSnapshot(_ snapshot: DexterFileWorkspaceIndexSnapshot) {
        let url = indexFileURL(for: snapshot.workspaceId)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private func indexFileURL(for workspaceId: UUID) -> URL {
        indexDirectoryURL.appendingPathComponent("dexter-file-workspace-index-\(workspaceId.uuidString).json")
    }
}
