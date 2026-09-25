//
//  DexterRoutineCapabilityResolver.swift
//  leanring-buddy
//

import Foundation

enum DexterRoutineCapabilityResolver {
    static func requiredCapabilities(forInstruction instruction: String) -> [DexterProductCapabilityID] {
        let normalized = instruction.lowercased()
        var capabilities: [DexterProductCapabilityID] = []

        if normalized.contains("remember") || normalized.contains("memory") || normalized.contains("study plan") {
            capabilities.append(.memoryPersistent)
        }
        if normalized.contains("calendar") || normalized.contains("meeting") {
            capabilities.append(.researchConversation)
        }
        if normalized.contains("github") {
            capabilities.append(.researchConversation)
        }
        if normalized.contains("browser") || normalized.contains("website") || normalized.contains("search the web") {
            capabilities.append(.browserNavigation)
        }
        if normalized.contains("screen") || normalized.contains("what's on") {
            capabilities.append(.screenContext)
        }
        if normalized.contains("click") || normalized.contains("open app") || normalized.contains("computer") {
            capabilities.append(.computerControl)
        }

        return Array(Set(capabilities))
    }

    static func unavailableCapabilityLabels(
        requiredCapabilityIDs: [DexterProductCapabilityID],
        availableCapabilities: [DexterProductCapability]
    ) -> [String] {
        requiredCapabilityIDs.compactMap { capabilityID in
            let match = availableCapabilities.first { $0.capabilityID == capabilityID }
            guard let match else {
                return capabilityID.rawValue
            }
            if match.availability == .available {
                return nil
            }
            return match.displayName
        }
    }
}
