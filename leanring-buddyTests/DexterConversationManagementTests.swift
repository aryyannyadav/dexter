//
//  DexterConversationManagementTests.swift
//  leanring-buddyTests
//

import XCTest
@testable import leanring_buddy

final class DexterConversationManagementTests: XCTestCase {
    func testVisionDisplayTextStripsObservationJSON() {
        let raw = """
        You're in VS Code editing a Swift file.

        {"observations":[{"target":"Save","text":"Save","uiElement":"button","location":"toolbar","confidence":0.8,"state":"enabled"}]}
        """
        let display = DexterVisionObservationParser.userFacingChatDisplayText(from: raw)
        XCTAssertTrue(display.contains("VS Code"))
        XCTAssertFalse(display.contains("\"observations\""))
    }
}
