//
//  DexterProfileStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterProfileStore: ObservableObject {
    @Published private(set) var profiles: [DexterProfile] = []
    @Published private(set) var activeProfileId: UUID?

    var activeProfile: DexterProfile? {
        guard let activeProfileId else { return profiles.first }
        return profiles.first { $0.id == activeProfileId }
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dexterDirectory = supportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        self.fileURL = fileURL ?? dexterDirectory.appendingPathComponent("dexter-profiles.json")
        loadFromDisk()
    }

    func profile(withId profileId: UUID) -> DexterProfile? {
        profiles.first { $0.id == profileId }
    }

    func setActiveProfile(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileId = id
        UserDefaults.standard.set(id.uuidString, forKey: Self.activeProfileUserDefaultsKey)
    }

    func createProfile(
        name: String,
        purpose: String,
        description: String = "",
        connectedIntegrations: [String] = [],
        workspace: DexterProfileWorkspace = .empty,
        profileIdentifier: UUID? = nil,
        colorHex: String = "#5CE1E6",
        enabledSkills: [String] = [],
        characterAppearance: DexterCharacterAppearance? = nil
    ) -> DexterProfile {
        let now = Date()
        let resolvedProfileIdentifier = profileIdentifier ?? UUID()
        let profile = DexterProfile(
            id: resolvedProfileIdentifier,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            avatar: DexterProfileAvatar(symbolName: "person.crop.circle"),
            colorHex: colorHex,
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            memoryScope: .isolated,
            conversationID: UUID(),
            workspace: workspace,
            connectedIntegrations: connectedIntegrations,
            enabledSkills: enabledSkills,
            workSuggestions: [],
            permissions: .defaultPermissions,
            characterAppearance: characterAppearance,
            createdAt: now,
            updatedAt: now
        )
        profiles.append(profile)
        if activeProfileId == nil {
            activeProfileId = profile.id
        }
        persistToDisk()
        return profile
    }

    func createProfileFromOnboardingDraft(_ draft: DexterOnboardingProfileDraft) -> DexterProfile? {
        guard let archetype = draft.archetype else { return nil }
        let resolvedPurpose: String
        if archetype == .custom {
            resolvedPurpose = draft.customPurposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            resolvedPurpose = archetype.defaultPurpose
        }
        let profile = createProfile(
            name: draft.name,
            purpose: resolvedPurpose,
            description: draft.roleLine,
            connectedIntegrations: archetype.connectedIntegrations,
            workspace: .empty,
            profileIdentifier: archetype.stableProfileSeedIdentifier,
            colorHex: archetype.accentColorHex,
            enabledSkills: archetype.enabledSkills,
            characterAppearance: draft.characterAppearance
        )
        setActiveProfile(id: profile.id)
        return profile
    }

    func updateProfile(_ profile: DexterProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        updated.updatedAt = Date()
        profiles[index] = updated
        persistToDisk()
    }

    func updatePrimaryConversation(profileId: UUID, conversationId: UUID) {
        guard var profile = profile(withId: profileId) else { return }
        profile.conversationID = conversationId
        updateProfile(profile)
    }

    func refreshCachedWorkSuggestions(profileId: UUID, suggestions: [DexterProfileWorkSuggestion]) {
        guard var profile = profile(withId: profileId) else { return }
        profile.workSuggestions = suggestions
        updateProfile(profile)
    }

    func updateCharacterAppearance(profileId: UUID, appearance: DexterCharacterAppearance) {
        guard var profile = profile(withId: profileId) else { return }
        profile.characterAppearance = appearance
        updateProfile(profile)
    }

    private func loadFromDisk() {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(DexterProfileStoreSnapshot.self, from: data),
           !decoded.profiles.isEmpty {
            profiles = decoded.profiles
            activeProfileId = decoded.activeProfileId ?? decoded.profiles.first?.id
        } else {
            profiles = []
            activeProfileId = nil
            persistToDisk()
        }

        if activeProfileId == nil {
            activeProfileId = profiles.first?.id
        }

        if let storedActiveId = UserDefaults.standard.string(forKey: Self.activeProfileUserDefaultsKey),
           let uuid = UUID(uuidString: storedActiveId),
           profiles.contains(where: { $0.id == uuid }) {
            activeProfileId = uuid
        }
    }

    private func persistToDisk() {
        let snapshot = DexterProfileStoreSnapshot(profiles: profiles, activeProfileId: activeProfileId)
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        try? encoded.write(to: fileURL, options: [.atomic])
    }

    private static let activeProfileUserDefaultsKey = "dexterActiveProfileIdentifier"
}

private struct DexterProfileStoreSnapshot: Codable {
    let profiles: [DexterProfile]
    let activeProfileId: UUID?
}

enum DexterProfileSeedFactory {
    static func seedProfiles() -> [DexterProfile] {
        let createdAt = Date()
        return [
            DexterProfile(
                id: DexterSeedProfileIdentifier.studyBuddy,
                name: "Study Buddy",
                description: "CSE, university and learning",
                avatar: DexterProfileAvatar(symbolName: "book.closed"),
                colorHex: "#A78BFA",
                purpose: "CSE, university and learning",
                memoryScope: .isolated,
                conversationID: UUID(),
                workspace: DexterProfileWorkspace(label: "Courses"),
                connectedIntegrations: ["browser"],
                enabledSkills: [DexterSkillIdentifier.study.rawValue, DexterSkillIdentifier.research.rawValue],
                workSuggestions: [],
                permissions: .defaultPermissions,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            DexterProfile(
                id: DexterSeedProfileIdentifier.builder,
                name: "Builder",
                description: "Projects, coding and product work",
                avatar: DexterProfileAvatar(symbolName: "hammer"),
                colorHex: "#5CE1E6",
                purpose: "Projects, coding and product work",
                memoryScope: .isolated,
                conversationID: UUID(),
                workspace: DexterProfileWorkspace(label: "Projects"),
                connectedIntegrations: ["openclaw-gateway", "vscode", "terminal", "github"],
                enabledSkills: [
                    DexterSkillIdentifier.coding.rawValue,
                    DexterSkillIdentifier.developmentEnvironment.rawValue,
                    DexterSkillIdentifier.productivity.rawValue
                ],
                workSuggestions: [],
                permissions: .defaultPermissions,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            DexterProfile(
                id: DexterSeedProfileIdentifier.researcher,
                name: "Researcher",
                description: "Research, notes and knowledge",
                avatar: DexterProfileAvatar(symbolName: "doc.text.magnifyingglass"),
                colorHex: "#F59E0B",
                purpose: "Research, notes and knowledge",
                memoryScope: .isolated,
                conversationID: UUID(),
                workspace: DexterProfileWorkspace(label: "Reading"),
                connectedIntegrations: ["browser", "github"],
                enabledSkills: [
                    DexterSkillIdentifier.research.rawValue,
                    DexterSkillIdentifier.browserResearch.rawValue
                ],
                workSuggestions: [],
                permissions: .defaultPermissions,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            DexterProfile(
                id: DexterSeedProfileIdentifier.personal,
                name: "Personal",
                description: "Personal tasks and planning",
                avatar: DexterProfileAvatar(symbolName: "calendar"),
                colorHex: "#34D399",
                purpose: "Personal tasks and planning",
                memoryScope: .isolated,
                conversationID: UUID(),
                workspace: DexterProfileWorkspace(label: "Life"),
                connectedIntegrations: [],
                enabledSkills: [DexterSkillIdentifier.productivity.rawValue, DexterSkillIdentifier.fileOrganization.rawValue],
                workSuggestions: [],
                permissions: .defaultPermissions,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }
}
