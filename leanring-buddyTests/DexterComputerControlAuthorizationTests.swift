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

    @Test func sessionAuthorizationDoesNotSkipTypeTextConfirmation() {
        let typeText = DexterActionFactory.typeText("hello")
        #expect(
            DexterActionConfirmationPolicy.requiresUserConfirmation(
                action: typeText,
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
