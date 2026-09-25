//
//  DexterCommandNavigation.swift
//  leanring-buddy
//

import AppKit
import Foundation

@MainActor
enum DexterCommandNavigation {
    static func perform(
        action: DexterCommandResultAction,
        companionManager: CompanionManager,
        settingsRouter: DexterSettingsRouter
    ) {
        switch action {
        case .openConversation(let conversationId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            if let conversation = companionManager.dexterRecentConversations.first(where: { $0.id == conversationId }) {
                companionManager.openRecentDexterConversation(conversation)
            }

        case .openDexterProfile(let profileId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.openDexterProfileWorkspace(profileId: profileId)
            companionManager.pendingUniversalCommandProfileId = profileId

        case .openWorkspace(let profileId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.openDexterProfileWorkspace(profileId: profileId)
            companionManager.pendingUniversalCommandProfileId = profileId

        case .openFile(let profileId, let fileContext):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.openDexterProfileWorkspace(profileId: profileId)
            companionManager.dexterFileWorkspaceService.openFile(fileContext)

        case .openRoutine(let routineId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.pendingUniversalCommandRoutineId = routineId

        case .runRoutine(let routineId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.runDexterRoutine(routineID: routineId, runKind: .manual)

        case .openSettings(let page):
            settingsRouter.open(page: page)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        case .openCapability(let capabilityID):
            let page = settingsPage(for: capabilityID)
            settingsRouter.open(page: page)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        case .newChat:
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.startNewDexterConversation()

        case .askDexter(let query):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.pendingUniversalCommandComposerText = query
            NotificationCenter.default.post(name: .dexterHomeFocusChat, object: nil)

        case .showRoutinesList:
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.shouldPresentRoutinesList = true

        case .fixWorkspaceAccess(let profileId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.pendingUniversalCommandProfileId = profileId

        case .openHome:
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)

        case .openActivity(_, let profileId):
            NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
            companionManager.presentDexterActivityBrowser(profileId: profileId)
        }
    }

    private static func settingsPage(for capabilityID: DexterProductCapabilityID) -> DexterSettingsPage {
        switch capabilityID {
        case .computerControl, .computerLaunchApp, .computerPointer:
            return .computerControl
        case .screenContext, .screenUnderstanding:
            return .screenContext
        case .browserNavigation:
            return .integrations
        case .filesLocal, .terminalCommands:
            return .computerControl
        case .voiceRecognition, .voiceConversation:
            return .voice
        case .memoryPersistent:
            return .memory
        case .researchConversation:
            return .aiModels
        }
    }
}
