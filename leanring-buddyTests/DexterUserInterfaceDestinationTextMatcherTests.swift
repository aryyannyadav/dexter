//
//  DexterUserInterfaceDestinationTextMatcherTests.swift
//

import XCTest
@testable import leanring_buddy

final class DexterUserInterfaceDestinationTextMatcherTests: XCTestCase {
    func testNormalizeCollapsesWhitespace() {
        let normalized = DexterUserInterfaceDestinationTextMatcher.normalize("  Saved   Messages \n")
        XCTAssertEqual(normalized, "saved messages")
    }
}
