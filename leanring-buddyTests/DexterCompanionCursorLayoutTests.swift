//
//  DexterCompanionCursorLayoutTests.swift
//  leanring-buddyTests
//

import CoreGraphics
import XCTest
@testable import leanring_buddy

final class DexterCompanionCursorLayoutTests: XCTestCase {
    func testCharacterDrawHeightTargetsTwentyEightPoints() {
        let layout = DexterCompanionCursorLayout.layout(
            for: .spongeBob,
            intrinsicImageSize: CGSize(width: 96, height: 112)
        )
        XCTAssertEqual(layout.drawSize.height, DexterCompanionCursorMetrics.characterTargetHeight, accuracy: 0.01)
    }

    func testCharacterDrawSizePreservesAspectRatio() {
        let imageSize = CGSize(width: 112, height: 96)
        let layout = DexterCompanionCursorLayout.layout(
            for: .patrickStar,
            intrinsicImageSize: imageSize
        )

        XCTAssertEqual(
            layout.drawSize.width / layout.drawSize.height,
            imageSize.width / imageSize.height,
            accuracy: 0.001
        )
    }

    func testHotspotLandsAtFootprintCenter() {
        let layout = DexterCompanionCursorLayout.layout(
            for: .spongeBob,
            intrinsicImageSize: CGSize(width: 96, height: 112)
        )
        let hotspotFraction = DexterCursorStyleOption.spongeBob.layoutSpec.hotspotFraction
        let hotspotX = layout.drawSize.width * hotspotFraction.x + layout.imageTopLeadingOffset.width
        let hotspotY = layout.drawSize.height * hotspotFraction.y + layout.imageTopLeadingOffset.height

        XCTAssertEqual(hotspotX, layout.footprintSize.width / 2, accuracy: 0.01)
        XCTAssertEqual(hotspotY, layout.footprintSize.height / 2, accuracy: 0.01)
    }
}
