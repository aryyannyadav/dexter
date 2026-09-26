//
//  DexterComputerControlAuthorizationTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterComputerControlAuthorizationTests {
    @Test func sessionAuthorizationSkipsRepeatedOpenApplicationConfirmation() {
        let openSafari = DexterActionFactory.openApplication(named: "Safari")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: openSafari,
                settings: DexterActionPermissionSettings(autoApproveLowRiskActions: false),
                confirmationGrant: nil,
                isComputerControlAuthorizedForSession: true
            ) == false
        )
    }

    @Test func sessionAuthorizationSkipsRepeatedQuitApplicationConfirmation() {
        let quitSafari = DexterActionFactory.quitApplication(named: "Safari")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: quitSafari,
                settings: .default,
                confirmationGrant: nil,
                isComputerControlAuthorizedForSession: true
            ) == false
        )
    }

    @Test func sessionAuthorizationSkipsTypeTextConfirmation() {
        let typeText = DexterActionFactory.typeText("hello")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: typeText,
                settings: .default,
                confirmationGrant: nil,
                isComputerControlAuthorizedForSession: true
            ) == false
        )
    }

    @Test func explicitAllowGrantsPersistedComputerControlAuthorization() {
        let store = InMemoryDexterActionPermissionSettingsStore()
        #expect(!DexterComputerControlAuthorization.isUserAuthorized(store: store))
        DexterComputerControlAuthorization.grantUserAuthorization(store: store)
        #expect(DexterComputerControlAuthorization.isUserAuthorized(store: store))
    }

    @Test func persistedAuthorizationSurvivesStoreRecreation() {
        let suiteName = "dexter-computer-control-auth-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        let firstStore = UserDefaultsDexterActionPermissionSettingsStore(userDefaults: userDefaults)
        firstStore.isComputerControlAuthorizedForSession = true

        let secondStore = UserDefaultsDexterActionPermissionSettingsStore(userDefaults: userDefaults)
        #expect(secondStore.isComputerControlAuthorizedForSession)

        userDefaults.removePersistentDomain(forName: suiteName)
    }

    @Test func sessionAuthorizationDoesNotSkipDestructiveFileDelete() {
        let deleteFile = DexterAction(
            type: .fileOperation,
            parameters: ["fileAction": "delete", "path": "~/Documents/example.txt"],
            riskLevel: .highRisk,
            humanReadableDescription: "Delete example file."
        )
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: deleteFile,
                settings: .default,
                confirmationGrant: nil,
                isComputerControlAuthorizedForSession: true
            )
        )
    }

    @Test func sessionAuthorizationDoesNotSkipDestructiveRunTask() {
        let destructive = DexterActionFactory.runTask(instruction: "delete all files")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: destructive,
                settings: .default,
                confirmationGrant: nil,
                isComputerControlAuthorizedForSession: true
            )
        )
    }

    @Test func notchGeometryAnchorsPanelTopToDisplayTop() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let panelSize = CGSize(width: 320, height: 120)
        let frame = DexterNotchGeometry.centeredFrame(size: panelSize, screenFrame: screenFrame)
        #expect(frame.maxY == screenFrame.maxY)
        #expect(frame.midX == screenFrame.midX)
    }
}
