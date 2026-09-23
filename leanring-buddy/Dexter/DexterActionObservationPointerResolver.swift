//
//  DexterActionObservationPointerResolver.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterActionObservationPointerResolver {
    static func pointerLocationInScreenSpace(for action: DexterAction, context: DexterContext) -> CGPoint {
        if action.type == .click,
           let xCoordinate = Double(action.parameters["x"] ?? ""),
           let yCoordinate = Double(action.parameters["y"] ?? "") {
            return CGPoint(x: xCoordinate, y: yCoordinate)
        }
        return context.attention.pointerLocationInScreenSpace
    }
}
