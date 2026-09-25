//
//  DexterLogo.swift
//  leanring-buddy
//
//  Brand mark from asset catalog (`dexter_logo`).
//

import AppKit
import SwiftUI

enum DexterLogoStyle: Equatable {
    case standard
    case glow
    case monochrome(Color)
}

struct DexterLogo: View {
    var size: CGFloat
    var style: DexterLogoStyle
    var animated: Bool

    init(
        size: CGFloat = DexterMetrics.logoSizeInline,
        style: DexterLogoStyle = .standard,
        animated: Bool = false
    ) {
        self.size = size
        self.style = style
        self.animated = animated
    }

    var body: some View {
        Image(DexterBrandAssets.logoImageName)
            .renderingMode(renderingMode)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Dexter")
    }

    private var renderingMode: Image.TemplateRenderingMode? {
        switch style {
        case .monochrome:
            return .template
        case .standard, .glow:
            return .original
        }
    }
}

enum DexterBrandAssets {
    static let logoImageName = "dexter_logo"

    static func menuBarIcon(pointSize: CGFloat = DexterMetrics.logoSizeMenuBar) -> NSImage? {
        guard let image = NSImage(named: NSImage.Name(logoImageName)) else { return nil }
        image.size = NSSize(width: pointSize, height: pointSize)
        return image
    }
}

/// AppKit menu bar image from the brand asset.
enum DexterLogoMenuBarIcon {
    static func makeTemplateImage(pointSize: CGFloat = DexterMetrics.logoSizeMenuBar) -> NSImage {
        if let brandImage = DexterBrandAssets.menuBarIcon(pointSize: pointSize) {
            brandImage.isTemplate = false
            return brandImage
        }
        return NSImage(size: NSSize(width: pointSize, height: pointSize))
    }
}
