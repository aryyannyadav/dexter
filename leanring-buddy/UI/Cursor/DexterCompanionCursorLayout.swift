//
//  DexterCompanionCursorLayout.swift
//  leanring-buddy
//

import CoreGraphics
import SwiftUI

enum DexterCompanionCursorMetrics {
    static var classicTriangleDrawSize: CGFloat { 16 * DexterCursorSettingsStore.shared.sizeScaleMultiplier }
    /// Target rendered height for character cursors (24–32pt range).
    static var characterTargetHeight: CGFloat { 28 * DexterCursorSettingsStore.shared.sizeScaleMultiplier }
    static var characterMaximumWidth: CGFloat { 42 * DexterCursorSettingsStore.shared.sizeScaleMultiplier }
}

struct DexterCompanionCursorLayout {
    let footprintSize: CGSize
    let drawSize: CGSize
    /// Positions the image so the hotspot sits at the footprint center (SwiftUI top-leading offset).
    let imageTopLeadingOffset: CGSize

    static func layout(
        for style: DexterCursorStyleOption,
        intrinsicImageSize: CGSize
    ) -> DexterCompanionCursorLayout {
        switch style {
        case .classic:
            return classicLayout()
        case .spongeBob, .patrickStar:
            return characterLayout(for: style, intrinsicImageSize: intrinsicImageSize)
        }
    }

    private static func classicLayout() -> DexterCompanionCursorLayout {
        let triangleSize = DexterCompanionCursorMetrics.classicTriangleDrawSize
        return DexterCompanionCursorLayout(
            footprintSize: CGSize(width: triangleSize, height: triangleSize),
            drawSize: CGSize(width: triangleSize, height: triangleSize),
            imageTopLeadingOffset: .zero
        )
    }

    private static func characterLayout(
        for style: DexterCursorStyleOption,
        intrinsicImageSize: CGSize
    ) -> DexterCompanionCursorLayout {
        let spec = style.layoutSpec
        let aspectRatio = intrinsicImageSize.width / max(intrinsicImageSize.height, 1)

        var drawHeight = DexterCompanionCursorMetrics.characterTargetHeight * spec.footprintScaleMultiplier
        var drawWidth = drawHeight * aspectRatio

        if drawWidth > DexterCompanionCursorMetrics.characterMaximumWidth {
            drawWidth = DexterCompanionCursorMetrics.characterMaximumWidth
            drawHeight = drawWidth / max(aspectRatio, 0.01)
        }

        let drawSize = CGSize(width: drawWidth, height: drawHeight)
        let hotspotX = drawSize.width * spec.hotspotFraction.x
        let hotspotY = drawSize.height * spec.hotspotFraction.y

        let footprintWidth = max(hotspotX, drawSize.width - hotspotX) * 2
        let footprintHeight = max(hotspotY, drawSize.height - hotspotY) * 2
        let footprintSize = CGSize(width: footprintWidth, height: footprintHeight)

        let imageTopLeadingOffset = CGSize(
            width: footprintWidth / 2 - hotspotX,
            height: footprintHeight / 2 - hotspotY
        )

        return DexterCompanionCursorLayout(
            footprintSize: footprintSize,
            drawSize: drawSize,
            imageTopLeadingOffset: imageTopLeadingOffset
        )
    }
}

extension DexterCursorStyleOption {
    struct LayoutSpec {
        let footprintScaleMultiplier: CGFloat
        /// Pointing location within the image (0 = leading/top, 1 = trailing/bottom).
        let hotspotFraction: CGPoint
        let assetImageName: String?
    }

    var layoutSpec: LayoutSpec {
        switch self {
        case .classic:
            return LayoutSpec(
                footprintScaleMultiplier: 1.0,
                hotspotFraction: CGPoint(x: 0.5, y: 0.12),
                assetImageName: nil
            )
        case .spongeBob:
            return LayoutSpec(
                footprintScaleMultiplier: 1.0,
                hotspotFraction: CGPoint(x: 0.5, y: 0.94),
                assetImageName: DexterCompanionCursorAssets.spongeBobImageName
            )
        case .patrickStar:
            return LayoutSpec(
                footprintScaleMultiplier: 0.98,
                hotspotFraction: CGPoint(x: 0.5, y: 0.94),
                assetImageName: DexterCompanionCursorAssets.patrickStarImageName
            )
        }
    }

    var loadsCharacterArtwork: Bool {
        switch self {
        case .classic:
            return false
        case .spongeBob, .patrickStar:
            return true
        }
    }

    func intrinsicImageSizeInPoints() -> CGSize {
        guard let assetImageName = layoutSpec.assetImageName,
              let size = DexterCompanionCursorAssets.intrinsicImageSizeInPoints(for: assetImageName) else {
            return .zero
        }
        return size
    }
}
