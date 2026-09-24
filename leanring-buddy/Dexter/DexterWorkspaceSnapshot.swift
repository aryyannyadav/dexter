//
//  DexterWorkspaceSnapshot.swift
//  leanring-buddy
//
//  Semantic workspace state (no pointer coordinates or replay positions).
//

import Foundation

struct DexterWorkspaceApplicationReference: Codable, Equatable {
    let displayName: String
    let bundleIdentifier: String?
}

struct DexterWorkspaceWindowReference: Codable, Equatable {
    let applicationDisplayName: String?
    let windowTitle: String
}

struct DexterWorkspaceBrowserTabReference: Codable, Equatable {
    let browserApplicationName: String?
    let pageTitle: String?
    let pageURL: String?
}

struct DexterWorkspaceProjectReference: Codable, Equatable {
    let workspaceName: String?
    let activeFileName: String?
    let editorApplicationName: String?
}

struct DexterWorkspaceFileReference: Codable, Equatable {
    let displayName: String
    let absolutePath: String?
}

struct DexterWorkspaceSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    var capturedAt: Date
    var label: String?
    var frontmostApplication: DexterWorkspaceApplicationReference?
    var foregroundWindow: DexterWorkspaceWindowReference?
    var openApplications: [DexterWorkspaceApplicationReference]
    var browserTab: DexterWorkspaceBrowserTabReference?
    var project: DexterWorkspaceProjectReference?
    var activeTaskDescription: String?
    var activeAccountabilityTaskIdentifier: UUID?
    var activeAccountabilityTaskTitle: String?
    var workflowSummary: String?
    var relevantFiles: [DexterWorkspaceFileReference]

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        label: String? = nil,
        frontmostApplication: DexterWorkspaceApplicationReference? = nil,
        foregroundWindow: DexterWorkspaceWindowReference? = nil,
        openApplications: [DexterWorkspaceApplicationReference] = [],
        browserTab: DexterWorkspaceBrowserTabReference? = nil,
        project: DexterWorkspaceProjectReference? = nil,
        activeTaskDescription: String? = nil,
        activeAccountabilityTaskIdentifier: UUID? = nil,
        activeAccountabilityTaskTitle: String? = nil,
        workflowSummary: String? = nil,
        relevantFiles: [DexterWorkspaceFileReference] = []
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.label = label
        self.frontmostApplication = frontmostApplication
        self.foregroundWindow = foregroundWindow
        self.openApplications = openApplications
        self.browserTab = browserTab
        self.project = project
        self.activeTaskDescription = activeTaskDescription
        self.activeAccountabilityTaskIdentifier = activeAccountabilityTaskIdentifier
        self.activeAccountabilityTaskTitle = activeAccountabilityTaskTitle
        self.workflowSummary = workflowSummary
        self.relevantFiles = relevantFiles
    }
}

enum DexterWorkspaceSemanticMatching {
    static func normalizedApplicationToken(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "visual studio code", with: "vscode")
    }

    static func applicationsMatch(
        saved: DexterWorkspaceApplicationReference?,
        currentDisplayName: String?,
        currentBundleIdentifier: String?
    ) -> Bool {
        guard let saved else { return currentDisplayName == nil && currentBundleIdentifier == nil }

        if let savedBundle = saved.bundleIdentifier?.lowercased(),
           let currentBundle = currentBundleIdentifier?.lowercased(),
           !savedBundle.isEmpty,
           !currentBundle.isEmpty,
           savedBundle == currentBundle {
            return true
        }

        guard let currentDisplayName else { return false }
        let savedToken = normalizedApplicationToken(saved.displayName)
        let currentToken = normalizedApplicationToken(currentDisplayName)
        if savedToken == currentToken { return true }
        return savedToken.contains(currentToken) || currentToken.contains(savedToken)
    }

    static func normalizedURLString(_ rawURL: String?) -> String? {
        guard let rawURL else { return nil }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let components = URLComponents(string: trimmed) {
            var normalized = components
            normalized.fragment = nil
            if normalized.path == "/" {
                normalized.path = ""
            }
            return normalized.string?.lowercased()
        }
        return trimmed.lowercased()
    }

    static func browserTabsMatch(
        saved: DexterWorkspaceBrowserTabReference?,
        currentPageURL: String?,
        currentPageTitle: String?
    ) -> Bool {
        guard let saved else {
            return currentPageURL == nil && currentPageTitle == nil
        }

        if let savedURL = normalizedURLString(saved.pageURL),
           let currentURL = normalizedURLString(currentPageURL),
           savedURL == currentURL {
            return true
        }

        if let savedTitle = saved.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let currentTitle = currentPageTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !savedTitle.isEmpty,
           !currentTitle.isEmpty,
           savedTitle == currentTitle {
            return true
        }

        return saved.pageURL == nil && saved.pageTitle == nil
    }

    static func windowTitlesMatch(saved: DexterWorkspaceWindowReference?, currentTitle: String?) -> Bool {
        guard let saved else { return true }
        guard let currentTitle else { return false }
        let savedTitle = saved.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let currentNormalized = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if savedTitle == currentNormalized { return true }
        return savedTitle.contains(currentNormalized) || currentNormalized.contains(savedTitle)
    }
}
