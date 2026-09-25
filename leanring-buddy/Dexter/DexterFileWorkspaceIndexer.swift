//
//  DexterFileWorkspaceIndexer.swift
//  leanring-buddy
//

import Foundation

enum DexterFileWorkspaceIndexer {
    static let maxDirectoryDepth = 6
    static let maxIndexedFiles = 3_000
    static let maxTextSnippetCharacters = 2_000
    static let maxTextFileBytesForSnippet = 256_000

    struct IndexProgressUpdate: Sendable {
        let progress: Double
        let partialSnapshot: DexterFileWorkspaceIndexSnapshot?
    }

    static func contentKind(for url: URL) -> DexterFileWorkspaceContentKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown":
            return .markdown
        case "swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "java", "kt", "c", "cc", "cpp", "h", "m", "mm", "rb", "php", "sh", "zsh", "bash":
            return .sourceCode
        case "json":
            return .json
        case "csv":
            return .csv
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff":
            return .image
        case "txt", "log":
            return .text
        case "doc", "docx", "rtf", "pages":
            return .document
        default:
            return .other
        }
    }

    static func shouldSkipDirectory(name: String) -> Bool {
        let lowered = name.lowercased()
        if lowered.hasPrefix(".") && lowered != ".git" {
            return true
        }
        switch lowered {
        case "node_modules", "deriveddata", "build", ".build", "vendor", "pods", "carthage", ".svn":
            return true
        default:
            return false
        }
    }

    static func indexWorkspace(
        workspace: DexterFileWorkspace,
        resolvedLocations: [(location: DexterFileWorkspaceLocation, url: URL)],
        previousSnapshot: DexterFileWorkspaceIndexSnapshot?,
        onProgress: (@Sendable (IndexProgressUpdate) -> Void)? = nil
    ) -> (snapshot: DexterFileWorkspaceIndexSnapshot, folderCount: Int, fileCount: Int, gitSummary: DexterFileWorkspaceGitSummary?) {
        var discoveredFiles: [DexterFileContext] = []
        var folderCount = 0
        var processedFileCount = 0
        let previousByID = Dictionary(uniqueKeysWithValues: (previousSnapshot?.files ?? []).map { ($0.fileID, $0) })

        var gitSummary: DexterFileWorkspaceGitSummary?
        for resolved in resolvedLocations where resolved.location.kind == .folder {
            if let summary = DexterFileWorkspaceGitMetadataReader.readSummary(repositoryRootURL: resolved.url) {
                gitSummary = summary
                break
            }
        }

        let totalBudget = maxIndexedFiles
        for resolved in resolvedLocations {
            let location = resolved.location
            let rootURL = resolved.url
            if location.kind == .file {
                if let fileContext = fileContext(
                    forFileURL: rootURL,
                    workspaceId: workspace.id,
                    locationId: location.id,
                    previous: previousByID
                ) {
                    discoveredFiles.append(fileContext)
                    processedFileCount += 1
                }
                continue
            }

            folderCount += 1
            enumerateDirectory(
                directoryURL: rootURL,
                workspaceId: workspace.id,
                locationId: location.id,
                depth: 0,
                previousByID: previousByID,
                discoveredFiles: &discoveredFiles,
                folderCount: &folderCount,
                processedFileCount: &processedFileCount,
                totalBudget: totalBudget,
                onProgress: onProgress,
                workspaceIdForProgress: workspace.id
            )
            if processedFileCount >= totalBudget {
                break
            }
        }

        let snapshot = DexterFileWorkspaceIndexSnapshot(
            workspaceId: workspace.id,
            files: discoveredFiles,
            updatedAt: Date()
        )
        onProgress?(IndexProgressUpdate(progress: 1.0, partialSnapshot: snapshot))
        return (snapshot, folderCount, discoveredFiles.count, gitSummary)
    }

    private static func enumerateDirectory(
        directoryURL: URL,
        workspaceId: UUID,
        locationId: UUID,
        depth: Int,
        previousByID: [String: DexterFileContext],
        discoveredFiles: inout [DexterFileContext],
        folderCount: inout Int,
        processedFileCount: inout Int,
        totalBudget: Int,
        onProgress: (@Sendable (IndexProgressUpdate) -> Void)?,
        workspaceIdForProgress: UUID
    ) {
        guard depth <= maxDirectoryDepth, processedFileCount < totalBudget else { return }

        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let itemURL as URL in enumerator {
            if processedFileCount >= totalBudget { break }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if resourceValues?.isDirectory == true {
                if shouldSkipDirectory(name: itemURL.lastPathComponent) {
                    enumerator.skipDescendants()
                } else {
                    folderCount += 1
                }
                continue
            }
            guard resourceValues?.isRegularFile == true else { continue }

            if let fileContext = fileContext(
                forFileURL: itemURL,
                workspaceId: workspaceId,
                locationId: locationId,
                previous: previousByID
            ) {
                discoveredFiles.append(fileContext)
                processedFileCount += 1
                if processedFileCount % 40 == 0 {
                    let progress = min(0.98, Double(processedFileCount) / Double(totalBudget))
                    let partial = DexterFileWorkspaceIndexSnapshot(
                        workspaceId: workspaceIdForProgress,
                        files: discoveredFiles,
                        updatedAt: Date()
                    )
                    onProgress?(IndexProgressUpdate(progress: progress, partialSnapshot: partial))
                }
            }
        }
    }

    private static func fileContext(
        forFileURL fileURL: URL,
        workspaceId: UUID,
        locationId: UUID,
        previous: [String: DexterFileContext]
    ) -> DexterFileContext? {
        let standardizedPath = fileURL.standardizedFileURL.path
        let fileID = "\(workspaceId.uuidString):\(standardizedPath)"
        let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let byteSize = Int64(resourceValues?.fileSize ?? 0)
        let modifiedAt = resourceValues?.contentModificationDate

        if let previousFile = previous[fileID],
           previousFile.byteSize == byteSize,
           previousFile.modifiedAt == modifiedAt {
            return previousFile
        }

        let kind = contentKind(for: fileURL)
        var indexStatus: DexterFileIndexStatus = .metadataOnly
        var snippet: String?

        switch kind {
        case .text, .markdown, .sourceCode, .json, .csv:
            if byteSize <= maxTextFileBytesForSnippet {
                if let data = try? Data(contentsOf: fileURL),
                   let text = String(data: data, encoding: .utf8) {
                    snippet = String(text.prefix(maxTextSnippetCharacters))
                    indexStatus = .indexed
                } else {
                    indexStatus = .skippedUnsupported
                }
            } else {
                indexStatus = .metadataOnly
            }
        case .pdf, .image, .document, .other:
            indexStatus = .metadataOnly
        }

        return DexterFileContext(
            fileID: fileID,
            workspaceID: workspaceId,
            locationID: locationId,
            name: fileURL.lastPathComponent,
            absolutePath: standardizedPath,
            displayPath: DexterFileWorkspaceBookmarkAccess.tildeDisplayPath(for: standardizedPath),
            contentKind: kind,
            byteSize: byteSize,
            modifiedAt: modifiedAt,
            indexStatus: indexStatus,
            searchableTextSnippet: snippet,
            metadata: [:]
        )
    }
}
