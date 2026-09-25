//
//  DexterCapabilityAwareSuggestionModels.swift
//  leanring-buddy
//

import Foundation

enum DexterCapabilityRequirementKind: Equatable {
    case integrationConnect(integrationId: String, displayName: String)
    case openClawComputerControl
}

struct DexterCapabilityRequirement: Equatable {
    let kind: DexterCapabilityRequirementKind
    let intentSummary: String
}

struct DexterCapabilityAwareSuggestion: Equatable {
    let requirement: DexterCapabilityRequirement
    let headline: String
    let body: String
    let primaryActionTitle: String
    let integrationIdForSettings: String

    var persistenceIdentifier: String {
        switch requirement.kind {
        case .integrationConnect(let integrationId, _):
            return "capability_connect:\(integrationId)"
        case .openClawComputerControl:
            return "capability_connect:openclaw-computer-control"
        }
    }
}
