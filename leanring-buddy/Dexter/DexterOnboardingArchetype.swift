//
//  DexterOnboardingArchetype.swift
//  leanring-buddy
//

import Foundation

enum DexterOnboardingArchetype: String, CaseIterable, Equatable, Identifiable {
    case study
    case build
    case research
    case create
    case personal
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: return "Study Buddy"
        case .build: return "Builder"
        case .research: return "Researcher"
        case .create: return "Creator"
        case .personal: return "Personal"
        case .custom: return "Your Dexter"
        }
    }

    var subtitle: String {
        switch self {
        case .study:
            return "Learn, revise, and stay on top of coursework."
        case .build:
            return "Build projects, debug code, and work through technical problems."
        case .research:
            return "Read, organize, and reason through research."
        case .create:
            return "Write, design, brainstorm, and create."
        case .personal:
            return "Keep track of everyday tasks and plans."
        case .custom:
            return "Describe what you want Dexter to help with."
        }
    }

    var defaultRoleLine: String {
        switch self {
        case .study: return "Your study partner"
        case .build: return "Your coding companion"
        case .research: return "Your research assistant"
        case .create: return "Your creative companion"
        case .personal: return "Your personal computer companion"
        case .custom: return "Your personal computer companion"
        }
    }

    var defaultPurpose: String {
        switch self {
        case .study: return "Learning, revision, and coursework"
        case .build: return "Projects, coding, and technical work"
        case .research: return "Research, notes, and knowledge work"
        case .create: return "Writing, design, and creative work"
        case .personal: return "Personal tasks and planning"
        case .custom: return ""
        }
    }

    var characterID: String {
        switch self {
        case .study: return DexterCharacterCatalog.studyBuddyCharacterID
        case .build: return DexterCharacterCatalog.builderCharacterID
        case .research: return DexterCharacterCatalog.researcherCharacterID
        case .create, .personal, .custom: return DexterCharacterCatalog.personalCharacterID
        }
    }

    var accentColorHex: String {
        switch self {
        case .study: return "#A78BFA"
        case .build: return "#5CE1E6"
        case .research: return "#F59E0B"
        case .create: return "#F472B6"
        case .personal: return "#34D399"
        case .custom: return "#5CE1E6"
        }
    }

    var connectedIntegrations: [String] {
        switch self {
        case .study: return ["browser"]
        case .build: return ["openclaw-gateway", "vscode", "terminal", "github"]
        case .research: return ["browser", "github"]
        case .create: return ["browser"]
        case .personal: return []
        case .custom: return []
        }
    }

    var enabledSkills: [String] {
        switch self {
        case .study:
            return [DexterSkillIdentifier.study.rawValue, DexterSkillIdentifier.research.rawValue]
        case .build:
            return [
                DexterSkillIdentifier.coding.rawValue,
                DexterSkillIdentifier.developmentEnvironment.rawValue,
                DexterSkillIdentifier.productivity.rawValue
            ]
        case .research:
            return [
                DexterSkillIdentifier.research.rawValue,
                DexterSkillIdentifier.browserResearch.rawValue
            ]
        case .create:
            return [DexterSkillIdentifier.productivity.rawValue]
        case .personal:
            return [
                DexterSkillIdentifier.productivity.rawValue,
                DexterSkillIdentifier.fileOrganization.rawValue
            ]
        case .custom:
            return [DexterSkillIdentifier.productivity.rawValue]
        }
    }

    var stableProfileSeedIdentifier: UUID? {
        switch self {
        case .study: return DexterSeedProfileIdentifier.studyBuddy
        case .build: return DexterSeedProfileIdentifier.builder
        case .research: return DexterSeedProfileIdentifier.researcher
        case .personal: return DexterSeedProfileIdentifier.personal
        case .create, .custom: return nil
        }
    }

    var workspacePrompt: String {
        switch self {
        case .study:
            return "Choose your notes or coursework folder."
        case .build:
            return "Choose your project folder."
        case .research:
            return "Choose your research folder."
        case .create:
            return "Choose a folder for your creative work."
        case .personal:
            return "Choose a folder if you want Dexter to work with local files."
        case .custom:
            return "Choose a folder for the work this Dexter will help with."
        }
    }

    var firstRunSuggestionPrompt: String {
        switch self {
        case .study:
            return "Help me plan today's study session."
        case .build:
            return "Show me what's wrong with my current code."
        case .research:
            return "Help me summarize what I'm reading."
        case .create:
            return "Help me brainstorm ideas for my project."
        case .personal:
            return "What should I focus on today?"
        case .custom:
            return "What do you want to do?"
        }
    }

    static var selectableArchetypes: [DexterOnboardingArchetype] {
        [.study, .build, .research, .create, .personal]
    }
}
