//
//  DexterTeachingPacketPromptBuilder.swift
//  leanring-buddy
//

import Foundation

enum DexterTeachingPacketPromptBuilder {
    static func contextSummary(from contextPacket: DexterContextPacket) -> String {
        var lines: [String] = []

        if let pointerTarget = contextPacket.pointerTarget?.semanticTarget
            ?? contextPacket.pointer?.semanticTarget {
            lines.append("pointer target: \(pointerTarget.modelSummaryLine)")
        } else if contextPacket.pointer != nil {
            lines.append("pointer location collected (no semantic target yet)")
        }

        if let application = contextPacket.activeApplication,
           application.availability == .available,
           let name = application.localizedName {
            lines.append("active application: \(name)")
        }

        if let window = contextPacket.activeWindow,
           window.availability == .available,
           let title = window.title {
            lines.append("active window: \(title)")
        }

        if let screenContext = contextPacket.screenContext {
            switch screenContext.captureAvailability {
            case .available:
                let count = screenContext.allScreens.count
                lines.append("screen capture: \(count) on-demand image(s) for this turn")
            case .permissionMissing:
                lines.append("screen capture: permission missing")
            case .notApplicable:
                lines.append("screen capture: not requested")
            case .unavailable(let errorDescription):
                lines.append("screen capture: unavailable (\(errorDescription))")
            }
        }

        if lines.isEmpty {
            return "minimal context packet (no pointer, app, or screen sections collected)"
        }
        return lines.joined(separator: "\n")
    }
}
