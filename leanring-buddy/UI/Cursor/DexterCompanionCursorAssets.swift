//
//  DexterCompanionCursorAssets.swift
//  leanring-buddy
//

import AppKit
import Foundation

/// Asset catalog image names for character cursors (Settings preview + overlay use the same names).
enum DexterCompanionCursorAssets {
    static let spongeBobImageName = "spongebob_cursor"
    static let patrickStarImageName = "patrick_cursor"

    static let previewMaximumBounds: CGFloat = 42

    private static var loggedMissingAssetNames = Set<String>()

    static func intrinsicImageSizeInPoints(for imageName: String) -> CGSize? {
        guard let image = NSImage(named: NSImage.Name(imageName)) else {
            reportMissingAssetIfNeeded(imageName)
            return nil
        }

        if image.size.width > 2, image.size.height > 2 {
            return image.size
        }

        let pixelSize = largestRepresentationPixelSize(for: image)
        guard pixelSize.width > 2, pixelSize.height > 2 else {
            reportMissingAssetIfNeeded(imageName)
            return nil
        }
        return pixelSize
    }

    static func isCharacterArtworkAvailable(for style: DexterCursorStyleOption) -> Bool {
        guard let imageName = style.layoutSpec.assetImageName else { return false }
        return intrinsicImageSizeInPoints(for: imageName) != nil
    }

    static func reportMissingAssetIfNeeded(_ imageName: String) {
        guard loggedMissingAssetNames.insert(imageName).inserted else { return }
        NSLog("[DEXTER][CURSOR] Asset catalog image not loaded: %@", imageName)
    }

    private static func largestRepresentationPixelSize(for image: NSImage) -> CGSize {
        let largestRepresentation = image.representations.max { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        }
        guard let largestRepresentation else { return .zero }
        return CGSize(
            width: CGFloat(max(largestRepresentation.pixelsWide, 0)),
            height: CGFloat(max(largestRepresentation.pixelsHigh, 0))
        )
    }
}
