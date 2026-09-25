//
//  DexterSettingsPage.swift
//  leanring-buddy
//

import Foundation

/// Primary navigation destinations for the Dexter settings window.
enum DexterSettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case cursor
    case voice
    case myDexters
    case memory
    case suggestions
    case screenContext
    case computerControl
    case integrations
    case privacy
    case permissions
    case aiModels
    case developer

    var id: String { rawValue }

    var navigationTitle: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .cursor: return "Cursor"
        case .voice: return "Voice"
        case .myDexters: return "My Dexters"
        case .memory: return "Memory"
        case .suggestions: return "Suggestions"
        case .screenContext: return "Screen Context"
        case .computerControl: return "Computer Control"
        case .integrations: return "Integrations"
        case .privacy: return "Privacy"
        case .permissions: return "Permissions"
        case .aiModels: return "AI & Models"
        case .developer: return "Developer"
        }
    }

    var sidebarSystemImage: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .cursor: return "cursorarrow"
        case .voice: return "waveform"
        case .myDexters: return "person.2"
        case .memory: return "brain"
        case .suggestions: return "lightbulb"
        case .screenContext: return "display"
        case .computerControl: return "desktopcomputer"
        case .integrations: return "puzzlepiece.extension"
        case .privacy: return "hand.raised"
        case .permissions: return "lock.shield"
        case .aiModels: return "cpu"
        case .developer: return "hammer"
        }
    }

    var sidebarSection: DexterSettingsSidebarSectionKind {
        switch self {
        case .general, .appearance, .cursor, .voice:
            return .general
        case .myDexters, .memory, .suggestions:
            return .dexter
        case .screenContext, .computerControl, .integrations:
            return .capabilities
        case .privacy, .permissions:
            return .system
        case .aiModels, .developer:
            return .advanced
        }
    }

    /// Pages shown in the sidebar (excludes hidden auxiliary routes).
    static var sidebarPages: [DexterSettingsPage] {
        allCases
    }
}

enum DexterSettingsSidebarSectionKind: String, CaseIterable {
    case general = "GENERAL"
    case dexter = "DEXTER"
    case capabilities = "CAPABILITIES"
    case system = "SYSTEM"
    case advanced = "ADVANCED"

    var pages: [DexterSettingsPage] {
        DexterSettingsPage.sidebarPages.filter { $0.sidebarSection == self }
    }
}

struct DexterSettingsSearchEntry: Identifiable, Hashable {
    let id: String
    let page: DexterSettingsPage
    let title: String
    let keywords: String
}

enum DexterSettingsSearchIndex {
    static let entries: [DexterSettingsSearchEntry] = [
        DexterSettingsSearchEntry(id: "launch-login", page: .general, title: "Launch at login", keywords: "startup sign in"),
        DexterSettingsSearchEntry(id: "open-home", page: .general, title: "Open Home when Dexter launches", keywords: "window startup"),
        DexterSettingsSearchEntry(id: "theme", page: .appearance, title: "Theme", keywords: "dark system appearance"),
        DexterSettingsSearchEntry(id: "accent", page: .appearance, title: "Accent color", keywords: "color highlight"),
        DexterSettingsSearchEntry(id: "cursor-style", page: .cursor, title: "Cursor style", keywords: "classic spongebob patrick"),
        DexterSettingsSearchEntry(id: "cursor-size", page: .cursor, title: "Cursor size", keywords: "small large"),
        DexterSettingsSearchEntry(id: "push-to-talk", page: .voice, title: "Push to talk", keywords: "microphone voice input"),
        DexterSettingsSearchEntry(id: "spoken-responses", page: .voice, title: "Spoken responses", keywords: "voice output tts"),
        DexterSettingsSearchEntry(id: "memory-clear", page: .memory, title: "Clear Dexter memories", keywords: "forget saved"),
        DexterSettingsSearchEntry(id: "suggestions", page: .suggestions, title: "Suggestions", keywords: "home notch"),
        DexterSettingsSearchEntry(id: "screen-context", page: .screenContext, title: "Screen context", keywords: "capture screenshot"),
        DexterSettingsSearchEntry(id: "computer-control", page: .computerControl, title: "Computer control", keywords: "actions openclaw"),
        DexterSettingsSearchEntry(id: "integrations", page: .integrations, title: "Integrations", keywords: "connectors github"),
        DexterSettingsSearchEntry(id: "permissions", page: .permissions, title: "Permissions", keywords: "microphone screen accessibility"),
        DexterSettingsSearchEntry(id: "ollama", page: .aiModels, title: "Ollama models", keywords: "local qwen vision text"),
        DexterSettingsSearchEntry(id: "developer", page: .developer, title: "Developer mode", keywords: "diagnostics logs")
    ]

    static func matchingEntries(query: String) -> [DexterSettingsSearchEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return entries.filter { entry in
            entry.title.lowercased().contains(trimmed)
                || entry.keywords.lowercased().contains(trimmed)
                || entry.page.navigationTitle.lowercased().contains(trimmed)
        }
    }
}
