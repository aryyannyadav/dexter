//
//  DexterFirstRunOnboardingStore.swift
//  leanring-buddy
//

import Combine
import Foundation

enum DexterFirstRunOnboardingStep: Int, CaseIterable, Equatable {
    case welcome = 0
    case purpose = 1
    case customPurpose = 2
    case identity = 3
    case workspace = 4
    case permissions = 5
    case ready = 6

    var progressGroupIndex: Int {
        switch self {
        case .welcome:
            return 0
        case .purpose, .customPurpose:
            return 1
        case .identity:
            return 2
        case .workspace, .permissions:
            return 3
        case .ready:
            return 4
        }
    }

    static let progressGroupCount = 4

    static let progressGroupLabels = ["Choose", "Customize", "Connect", "Ready"]

    var usesInteractiveDesktop: Bool { false }
}

struct DexterOnboardingProfileDraft: Equatable {
    var archetype: DexterOnboardingArchetype?
    var customPurposeText: String = ""
    var name: String = ""
    var roleLine: String = ""
    var characterAppearance: DexterCharacterAppearance = DexterCharacterAppearance.defaultAppearance(
        forCharacterID: DexterCharacterCatalog.personalCharacterID
    )
    var workspaceURLs: [URL] = []
    var workspaceName: String = ""
    var workspaceDisplayLabel: String = ""
    var didSkipWorkspace = false
}

@MainActor
final class DexterFirstRunOnboardingStore: ObservableObject {
    @Published private(set) var currentStep: DexterFirstRunOnboardingStep = .welcome
    @Published var profileDraft = DexterOnboardingProfileDraft()
    @Published private(set) var hasFinishedProductOnboarding = false
    @Published var isCharacterCustomizePresented = false

    var canAdvanceFromCurrentStep: Bool {
        switch currentStep {
        case .welcome, .workspace, .permissions, .ready:
            return true
        case .purpose:
            return profileDraft.archetype != nil && profileDraft.archetype != .custom
        case .customPurpose:
            return !profileDraft.customPurposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .identity:
            return !profileDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !profileDraft.roleLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func beginIfNeeded() {
        DexterOnboardingStateStore.recordInProgress()
        DexterAnalytics.trackOnboardingStarted()
        DexterAnalytics.trackFirstRunOnboardingStepViewed(step: currentStep)
    }

    func selectArchetype(_ archetype: DexterOnboardingArchetype) {
        profileDraft.archetype = archetype
        if archetype == .custom {
            return
        }
        profileDraft.name = archetype.title
        profileDraft.roleLine = archetype.defaultRoleLine
        if let definition = DexterCharacterCatalog.character(withID: archetype.characterID) {
            profileDraft.characterAppearance = definition.defaultAppearance
        } else {
            profileDraft.characterAppearance = DexterCharacterAppearance.defaultAppearance(
                forCharacterID: archetype.characterID
            )
        }
        DexterAnalytics.trackOnboardingArchetypeSelected(archetype.rawValue)
    }

    func applyCustomPurposeDraft() {
        profileDraft.archetype = .custom
        let trimmedPurpose = profileDraft.customPurposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        profileDraft.name = suggestedNameFromCustomPurpose(trimmedPurpose)
        profileDraft.roleLine = DexterOnboardingArchetype.custom.defaultRoleLine
        profileDraft.characterAppearance = DexterCharacterAppearance.defaultAppearance(
            forCharacterID: DexterOnboardingArchetype.custom.characterID
        )
        DexterAnalytics.trackOnboardingArchetypeSelected("custom")
    }

    func advanceToNextStep() {
        guard canAdvanceFromCurrentStep else { return }

        if currentStep == .purpose, profileDraft.archetype == .custom {
            currentStep = .customPurpose
            trackStepViewed()
            return
        }

        guard let nextStep = DexterFirstRunOnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = nextStep
        trackStepViewed()
    }

    func goBackToPreviousStep() {
        if currentStep == .customPurpose {
            currentStep = .purpose
            return
        }
        if currentStep == .identity, profileDraft.archetype == .custom {
            currentStep = .customPurpose
            return
        }
        guard let previousStep = DexterFirstRunOnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previousStep
    }

    func jumpToPurposeWithCustomOption() {
        profileDraft.archetype = .custom
        currentStep = .customPurpose
        trackStepViewed()
    }

    func restartForReplay() {
        profileDraft = DexterOnboardingProfileDraft()
        hasFinishedProductOnboarding = false
        currentStep = .welcome
        DexterAnalytics.trackOnboardingReplayed()
    }

    func markFinished() {
        hasFinishedProductOnboarding = true
        DexterOnboardingStateStore.recordCompleted()
    }

    func markSkipped() {
        hasFinishedProductOnboarding = true
        DexterOnboardingStateStore.recordSkipped()
    }

    private func trackStepViewed() {
        DexterAnalytics.trackFirstRunOnboardingStepViewed(step: currentStep)
    }

    private func suggestedNameFromCustomPurpose(_ purpose: String) -> String {
        let words = purpose.split(separator: " ").prefix(3).map(String.init)
        guard !words.isEmpty else { return "My Dexter" }
        return words.joined(separator: " ")
    }
}
