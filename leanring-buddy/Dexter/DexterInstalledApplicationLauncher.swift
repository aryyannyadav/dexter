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
        let fileManager = FileManager.default
        let candidateNames = [
            "\(applicationName).app",
            applicationName.replacingOccurrences(of: " ", with: "") + ".app",
            applicationName.replacingOccurrences(of: " ", with: "-") + ".app"
        ]

        let searchRoots = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        for searchRoot in searchRoots {
            for candidateName in candidateNames {
                let candidatePath = (searchRoot as NSString).appendingPathComponent(candidateName)
                if fileManager.fileExists(atPath: candidatePath) {
                    return URL(fileURLWithPath: candidatePath)
                }
            }
        }

        return nil
    }
}
