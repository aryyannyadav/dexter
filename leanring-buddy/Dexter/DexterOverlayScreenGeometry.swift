//
//  DexterOverlayScreenGeometry.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterOverlayScreenGeometry {
    static func isSameDisplay(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.origin == rhs.origin && lhs.size == rhs.size
    }
}
