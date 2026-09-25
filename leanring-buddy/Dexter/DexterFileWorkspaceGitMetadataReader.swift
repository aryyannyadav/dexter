//
//  DexterFileWorkspaceGitMetadataReader.swift
//  leanring-buddy
//

import Foundation

enum DexterFileWorkspaceGitMetadataReader {
    static func readSummary(repositoryRootURL: URL) -> DexterFileWorkspaceGitSummary? {
        let gitDirectoryURL = repositoryRootURL.appendingPathComponent(".git", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: gitDirectoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        let branchName = readBranchName(gitDirectoryURL: gitDirectoryURL)
        let shortStatus = readShortStatus(repositoryRootURL: repositoryRootURL)

        return DexterFileWorkspaceGitSummary(
            isGitRepository: true,
            branchName: branchName,
            shortStatusSummary: shortStatus
        )
    }

    private static func readBranchName(gitDirectoryURL: URL) -> String? {
        let headURL = gitDirectoryURL.appendingPathComponent("HEAD")
        guard let headContents = try? String(contentsOf: headURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = headContents.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }
        if trimmed.count >= 7 {
            return String(trimmed.prefix(7)) + "…"
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func readShortStatus(repositoryRootURL: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--short"]
        process.currentDirectoryURL = repositoryRootURL

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let timeoutSeconds: TimeInterval = 5
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return "Unknown" }
        let trimmedLines = output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0) }
        if trimmedLines.isEmpty {
            return "Clean"
        }
        let changeCount = trimmedLines.count
        return "\(changeCount) change\(changeCount == 1 ? "" : "s")"
    }
}
