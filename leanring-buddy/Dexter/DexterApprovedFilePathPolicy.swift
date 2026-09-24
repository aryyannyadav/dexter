//
//  DexterApprovedFilePathPolicy.swift
//  leanring-buddy
//

import Foundation

enum DexterApprovedFilePathPolicy {
    static let maxReadBytes = 512_000
    static let maxWriteBytes = 512_000

    enum PathDecision: Equatable {
        case approved(resolvedURL: URL)
        case rejected(reason: String)
    }

    static func evaluate(path: String) -> PathDecision {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return .rejected(reason: "File path is empty.")
        }

        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
        let candidateURL = URL(fileURLWithPath: expandedPath, isDirectory: false)
        let resolvedURL = candidateURL.standardizedFileURL

        guard let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path as String? else {
            return .rejected(reason: "Could not resolve the home directory.")
        }

        let resolvedPath = resolvedURL.path
        if resolvedPath.contains("/.ssh")
            || resolvedPath.contains("/Library/Keychains")
            || resolvedPath.contains("/Library/Application Support/Dexter/Secrets") {
            return .rejected(reason: "Dexter does not access sensitive paths.")
        }

        let allowedRoots = approvedRootDirectories(homeDirectoryPath: homeDirectory)
        let isUnderAllowedRoot = allowedRoots.contains { rootPath in
            resolvedPath == rootPath || resolvedPath.hasPrefix(rootPath + "/")
        }

        guard isUnderAllowedRoot else {
            return .rejected(reason: "Path is outside Dexter-approved folders (Documents, Desktop, Downloads, and Dexter project files).")
        }

        if resolvedPath.contains("..") {
            return .rejected(reason: "Path traversal is not allowed.")
        }

        return .approved(resolvedURL: resolvedURL)
    }

    static func approvedRootDirectories(homeDirectoryPath: String) -> [String] {
        let homeURL = URL(fileURLWithPath: homeDirectoryPath, isDirectory: true).standardizedFileURL
        var roots = [
            homeURL.appendingPathComponent("Documents", isDirectory: true).path,
            homeURL.appendingPathComponent("Desktop", isDirectory: true).path,
            homeURL.appendingPathComponent("Downloads", isDirectory: true).path
        ]

        if let dexterSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Dexter", isDirectory: true) {
            roots.append(dexterSupport.standardizedFileURL.path)
        }

        return roots
    }
}
