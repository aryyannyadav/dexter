//
//  DexterMemoryPresentation.swift
//  leanring-buddy
//

import Foundation

enum DexterMemoryProfileGroup: String, CaseIterable, Identifiable {
    case preferences
    case project
    case workflow
    case facts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preferences: return "Preferences"
        case .project: return "Project"
        case .workflow: return "Workflow"
        case .facts: return "Facts"
        }
    }

    static func group(for memoryType: DexterMemoryType) -> DexterMemoryProfileGroup {
        switch memoryType {
        case .preference:
            return .preferences
        case .project:
            return .project
        case .workflow, .task:
            return .workflow
        case .semantic, .episodic, .commitment:
            return .facts
        }
    }
}

extension DexterStructuredMemoryRecord {
    var profileGroup: DexterMemoryProfileGroup {
        DexterMemoryProfileGroup.group(for: type)
    }

    var userFacingSummary: String {
        if let title, !title.isEmpty, title != content {
            return content
        }
        return content
    }

    var userFacingTitle: String {
        if let title, !title.isEmpty {
            return title
        }
        return profileGroup.title
    }

    var scopeLabel: String {
        switch scope {
        case .global:
            return "All Dexters"
        case .dexterProfile:
            return "This Dexter"
        case .workspace:
            return "This workspace"
        }
    }
}
