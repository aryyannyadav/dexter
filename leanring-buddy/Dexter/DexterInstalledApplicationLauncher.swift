//
//  DexterInstalledApplicationLauncher.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterInstalledApplicationLauncher {
    static func isApplicationInstalled(named applicationName: String) -> Bool {
        resolveApplicationURL(named: applicationName) != nil
    }

    @MainActor
    static func launchApplication(named applicationName: String) -> Bool {
        if let applicationURL = resolveApplicationURL(named: applicationName) {
            return NSWorkspace.shared.open(applicationURL)
        }
        return NSWorkspace.shared.launchApplication(applicationName)
    }

    static func resolveApplicationURL(named applicationName: String) -> URL? {
        if let bundleMatchedURL = resolveApplicationURL(matchingBundleIdentifier: applicationName) {
            return bundleMatchedURL
        }

        let fileManager = FileManager.default
        let candidateNames = [
            "\(applicationName).app",
            applicationName.replacingOccurrences(of: " ", with: "") + ".app",
            applicationName.replacingOccurrences(of: " ", with: "-") + ".app"
        ]

        let searchRoots = applicationSearchRoots()

        for searchRoot in searchRoots {
            for candidateName in candidateNames {
                let candidatePath = (searchRoot as NSString).appendingPathComponent(candidateName)
                if fileManager.fileExists(atPath: candidatePath) {
                    return URL(fileURLWithPath: candidatePath)
                }
            }
        }

        let normalizedQuery = DexterApplicationReferenceResolver.normalizeApplicationName(applicationName)
        return findInstalledApplicationURL(
            matchingNormalizedName: normalizedQuery,
            fileManager: fileManager,
            searchRoots: searchRoots
        )
    }

    static func resolveApplicationURL(matchingBundleIdentifier bundleIdentifier: String) -> URL? {
        let trimmedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedBundleIdentifier.contains(".") else { return nil }

        let fileManager = FileManager.default
        for searchRoot in applicationSearchRoots() {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchRoot),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let candidateURL as URL in enumerator {
                guard candidateURL.pathExtension == "app" else { continue }
                if Bundle(url: candidateURL)?.bundleIdentifier?.caseInsensitiveCompare(trimmedBundleIdentifier) == .orderedSame {
                    return candidateURL
                }
            }
        }

        return nil
    }

    private static func applicationSearchRoots() -> [String] {
        [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]
    }

    private static func findInstalledApplicationURL(
        matchingNormalizedName normalizedQuery: String,
        fileManager: FileManager,
        searchRoots: [String]
    ) -> URL? {
        guard !normalizedQuery.isEmpty else { return nil }

        for searchRoot in searchRoots {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchRoot),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let candidateURL as URL in enumerator {
                guard candidateURL.pathExtension == "app" else { continue }
                let candidateName = DexterApplicationReferenceResolver.normalizeApplicationName(
                    candidateURL.deletingPathExtension().lastPathComponent
                )
                if candidateName == normalizedQuery {
                    return candidateURL
                }
                if let bundleDisplayName = Bundle(url: candidateURL)?.object(forInfoDictionaryKey: "CFBundleName") as? String,
                   DexterApplicationReferenceResolver.normalizeApplicationName(bundleDisplayName) == normalizedQuery {
                    return candidateURL
                }
            }
        }

        return nil
    }
}
