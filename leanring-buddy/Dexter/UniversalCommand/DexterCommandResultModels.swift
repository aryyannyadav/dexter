//
//  DexterCommandResultModels.swift
//  leanring-buddy
//

import Foundation

enum DexterCommandResultKind: String, Equatable {
    case conversation
    case dexter
    case workspace
    case file
    case routine
    case memory
    case activity
    case setting
    case capability
    case action
    case suggestion
    case askDexter
}

enum DexterCommandResultGroup: String, Equatable, CaseIterable {
    case topResult
    case conversations
    case dexters
    case workspaces
    case files
    case routines
    case memories
    case activity
    case settings
    case capabilities
    case actions
    case suggestions
    case askDexter

    var title: String {
        switch self {
        case .topResult: return "TOP RESULT"
        case .conversations: return "CONVERSATIONS"
        case .dexters: return "DEXTERS"
        case .workspaces: return "WORKSPACES"
        case .files: return "FILES"
        case .routines: return "ROUTINES"
        case .memories: return "MEMORY"
        case .activity: return "ACTIVITY"
        case .settings: return "SETTINGS"
        case .capabilities: return "CAPABILITIES"
        case .actions: return "ACTIONS"
        case .suggestions: return "SUGGESTIONS"
        case .askDexter: return "ASK DEXTER"
        }
    }
}

enum DexterCommandResultAction: Equatable {
    case openConversation(conversationId: UUID)
    case openDexterProfile(profileId: UUID)
    case openWorkspace(profileId: UUID)
    case openFile(profileId: UUID, fileContext: DexterFileContext)
    case openRoutine(routineId: UUID)
    case runRoutine(routineId: UUID)
    case openSettings(page: DexterSettingsPage)
    case openCapability(capabilityID: DexterProductCapabilityID)
    case newChat
    case askDexter(query: String)
    case showRoutinesList
    case fixWorkspaceAccess(profileId: UUID)
    case openHome
    case openActivity(eventId: UUID, profileId: UUID?)
}

struct DexterCommandResult: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let kind: DexterCommandResultKind
    let group: DexterCommandResultGroup
    let systemImageName: String?
    let dexterProfileId: UUID?
    let rankScore: Int
    let primaryAction: DexterCommandResultAction
    let secondaryAction: DexterCommandResultAction?
    let secondaryActionTitle: String?
    let isUnavailable: Bool
    let unavailableReason: String?

    var accessibilityLabel: String {
        if let subtitle, !subtitle.isEmpty {
            return "\(title), \(subtitle)"
        }
        return title
    }
}

struct DexterCommandResultSection: Identifiable, Equatable {
    let group: DexterCommandResultGroup
    let results: [DexterCommandResult]

    var id: String { group.rawValue }
}

struct DexterUniversalCommandSearchContext: Equatable {
    let activeProfileId: UUID?
    let activeConversationId: UUID?
    let activeWorkspaceProfileId: UUID?
    let activeWorkspaceName: String?
}
