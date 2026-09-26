//
//  DexterVisionUITargetLocalizationTests.swift
//

import CoreGraphics
import XCTest
@testable import leanring_buddy

final class DexterVisionUITargetLocalizationTests: XCTestCase {
    func testParseFoundBoundingBox() {
        let raw = """
        {"uiTarget":{"found":true,"boundingBox":{"x":0.1,"y":0.2,"width":0.15,"height":0.05},"confidence":0.92}}
        """
        let result = DexterVisionUITargetLocalization.parse(rawText: raw)
        XCTAssertTrue(result.found)
        XCTAssertEqual(result.boundingBoxNormalizedTopLeft?.origin.x, 0.1)
        XCTAssertEqual(result.confidence, 0.92)
    }

    func testParseNotFound() {
        let raw = #"{"uiTarget":{"found":false,"boundingBox":null,"confidence":0.1}}"#
        let result = DexterVisionUITargetLocalization.parse(rawText: raw)
        XCTAssertFalse(result.found)
    }
}
