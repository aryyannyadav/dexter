//
//  OpenClawLocalEnvironment.swift
//  leanring-buddy
//

import Foundation

/// Resolves the bundled OpenClaw CLI inside `OpenClaw.app` and prepares a PATH that includes its Node runtime.
struct OpenClawLocalEnvironment {
    let openClawApplicationURL: URL
    let fileManager: FileManager

    init(
        openClawApplicationURL: URL = URL(fileURLWithPath: "/Applications/OpenClaw.app"),
        fileManager: FileManager = .default
    ) {
        self.openClawApplicationURL = openClawApplicationURL
        self.fileManager = fileManager
    }

    var isOpenClawApplicationInstalled: Bool {
        fileManager.fileExists(atPath: openClawApplicationURL.path)
    }

    var openClawExecutableURL: URL? {
        guard let binaryDirectoryURL = openClawBinaryDirectoryURL() else { return nil }
        let executableURL = binaryDirectoryURL.appendingPathComponent("openclaw")
        guard fileManager.fileExists(atPath: executableURL.path) else { return nil }
        return executableURL
    }

    func augmentedProcessEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let binaryDirectoryURL = openClawBinaryDirectoryURL() {
            let existingPath = environment["PATH"] ?? ""
            environment["PATH"] = "\(binaryDirectoryURL.path):\(existingPath)"
        }
        return environment
    }

    func openClawBinaryDirectoryURL() -> URL? {
        let architectureDirectoryName = currentArchitectureDirectoryName()
        let preferredDirectoryURL = openClawApplicationURL
            .appendingPathComponent("Contents/Resources/node-worker/\(architectureDirectoryName)/bin")
        if fileManager.fileExists(atPath: preferredDirectoryURL.path) {
            return preferredDirectoryURL
        }

        for fallbackArchitectureDirectoryName in ["arm64", "x86_64"]
            where fallbackArchitectureDirectoryName != architectureDirectoryName {
            let fallbackDirectoryURL = openClawApplicationURL
                .appendingPathComponent("Contents/Resources/node-worker/\(fallbackArchitectureDirectoryName)/bin")
            if fileManager.fileExists(atPath: fallbackDirectoryURL.path) {
                return fallbackDirectoryURL
            }
        }

        return nil
    }

    private func currentArchitectureDirectoryName() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }
}
