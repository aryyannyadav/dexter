//
//  DexterFileWorkspaceBookmarkAccess.swift
//  leanring-buddy
//

import Foundation

enum DexterFileWorkspaceBookmarkAccess {
    struct ResolvedAccess: Equatable {
        let url: URL
        let accessState: DexterFileWorkspaceAccessState
        let refreshedBookmarkData: Data?
    }

    static func makeBookmarkData(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return nil
        }
    }

    static func resolve(
        location: DexterFileWorkspaceLocation,
        fileManager: FileManager = .default
    ) -> ResolvedAccess? {
        if let bookmarkData = location.securityScopedBookmarkData {
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                let pathExists = fileManager.fileExists(atPath: resolvedURL.path)
                if !pathExists {
                    return ResolvedAccess(
                        url: resolvedURL,
                        accessState: .missing,
                        refreshedBookmarkData: isStale ? makeBookmarkData(for: resolvedURL) : nil
                    )
                }
                let startedAccess = resolvedURL.startAccessingSecurityScopedResource()
                if !startedAccess && !fileManager.isReadableFile(atPath: resolvedURL.path) {
                    return ResolvedAccess(
                        url: resolvedURL,
                        accessState: .permissionRequired,
                        refreshedBookmarkData: isStale ? makeBookmarkData(for: resolvedURL) : nil
                    )
                }
                let state: DexterFileWorkspaceAccessState = isStale ? .stale : .available
                return ResolvedAccess(
                    url: resolvedURL,
                    accessState: state,
                    refreshedBookmarkData: isStale ? makeBookmarkData(for: resolvedURL) : nil
                )
            } catch {
                if let fallbackPath = location.lastResolvedPath {
                    let fallbackURL = URL(fileURLWithPath: fallbackPath)
                    if fileManager.fileExists(atPath: fallbackURL.path) {
                        return ResolvedAccess(url: fallbackURL, accessState: .stale, refreshedBookmarkData: nil)
                    }
                }
                return nil
            }
        }

        if let path = location.lastResolvedPath {
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: url.path) {
                return ResolvedAccess(
                    url: url,
                    accessState: .available,
                    refreshedBookmarkData: makeBookmarkData(for: url)
                )
            }
            return ResolvedAccess(url: url, accessState: .missing, refreshedBookmarkData: nil)
        }

        return nil
    }

    static func tildeDisplayPath(for absolutePath: String) -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        if absolutePath.hasPrefix(homeDirectory) {
            return "~" + absolutePath.dropFirst(homeDirectory.count)
        }
        return absolutePath
    }

    static func suggestedDisplayName(for url: URL) -> String {
        let standardizedPath = url.standardizedFileURL.path
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        if standardizedPath.hasPrefix(homeDirectory) {
            let relative = String(standardizedPath.dropFirst(homeDirectory.count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let lastComponent = relative.split(separator: "/").last {
                return String(lastComponent)
            }
        }
        return url.lastPathComponent
    }

    static func suggestedWorkspaceName(for url: URL) -> String {
        suggestedDisplayName(for: url)
    }
}
