//
//  DexterNotchGeometry.swift
//  leanring-buddy
//

import AppKit
import CoreGraphics

enum DexterNotchGeometry {
    /// Built-in / notched display when available; otherwise main screen.
    static func preferredDisplayScreen() -> NSScreen {
        if let notchedScreen = NSScreen.screens.max(by: { lhs, rhs in
            lhs.safeAreaInsets.top < rhs.safeAreaInsets.top
        }), notchedScreen.safeAreaInsets.top > 20 {
            return notchedScreen
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    /// AppKit global Y for the top edge of the panel (aligned with the physical display top / menu bar).
    static func topAnchorY(for screen: NSScreen) -> CGFloat {
        screen.frame.maxY
    }

    static func centeredFrame(size: CGSize, on screen: NSScreen) -> CGRect {
        centeredFrame(size: size, screenFrame: screen.frame)
    }

    static func centeredFrame(size: CGSize, screenFrame: CGRect) -> CGRect {
        let originX = screenFrame.midX - (size.width / 2)
        let originY = screenFrame.maxY - size.height
        return CGRect(x: originX, y: originY, width: size.width, height: size.height)
    }
}
