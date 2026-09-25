//
//  DexterProfileIdentitySheet.swift
//  leanring-buddy
//

import SwiftUI

struct DexterProfileSheetPresentationItem: Identifiable, Equatable {
    let profileId: UUID
    var id: UUID { profileId }
}

/// Personal identity surface for a single Dexter profile (phase 6).
struct DexterProfileIdentitySheet: View {
    @ObservedObject var companionManager: CompanionManager
    let profileId: UUID
    var onChat: () -> Void
    var onEditCharacter: (DexterProfile) -> Void
    var onDismiss: () -> Void

    @State private var isMemoryDetailPresented = false
    @State private var isActivityDetailPresented = false
    @State private var didLoadIntegrations = false
    @State private var selectedProductCapability: DexterProductCapability?
    @State private var selectedRoutineId: UUID?
    @State private var isRoutineCreatePresented = false

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var profile: DexterProfile? {
        companionManager.dexterProfileStore.profile(withId: profileId)
    }

    var body: some View {
        Group {
            if let profile {
                sheetContent(profile: profile)
            } else {
                missingProfilePlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(profile?.accentColor.opacity(0.06) ?? DexterSurfaceColors.background)
        .background(DexterSurfaceColors.background)
        .onExitCommand(perform: onDismiss)
        .onAppear {
            companionManager.reloadDexterMemoryPresentation()
            companionManager.refreshDexterProductCapabilities()
            loadIntegrationsIfNeeded()
        }
        .sheet(item: $selectedProductCapability) { capability in
            DexterCapabilityDetailSheet(capability: capability)
        }
        .sheet(isPresented: $isMemoryDetailPresented) {
            NavigationStack {
                ScrollView {
                    DexterMemoryManagementView(
                        companionManager: companionManager,
                        scopedProfileId: profileId
                    )
                        .padding(DexterSpacing.lg)
                }
                .background(DexterSurfaceColors.background)
                .navigationTitle("Memory")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isMemoryDetailPresented = false }
                    }
                }
            }
            .frame(minWidth: 420, minHeight: 480)
        }
        .sheet(isPresented: $isActivityDetailPresented) {
            NavigationStack {
                DexterProfileActivityView(
                    companionManager: companionManager,
                    profileId: profileId,
                    showsDexterLabels: false
                )
                .padding(DexterSpacing.lg)
                .navigationTitle("Activity")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { isActivityDetailPresented = false }
                    }
                }
            }
            .frame(minWidth: 480, minHeight: 520)
        }
    }

    @ViewBuilder
    private func sheetContent(profile: DexterProfile) -> some View {
        VStack(spacing: 0) {
            headerToolbar(profile: profile)

            ScrollView {
                VStack(alignment: .leading, spacing: DexterSpacing.xl) {
                    profileHeroBand(profile: profile)
                    aboutSection(profile: profile)
                    memorySection(profile: profile)
                    DexterProfileFileWorkspaceSection(companionManager: companionManager, profile: profile)
                    skillsSection(profile: profile)
                    integrationsSection(profile: profile)
                    routinesSection(profile: profile)
                    activitySection(profile: profile)
                    permissionsSection(profile: profile)
                }
                .padding(.horizontal, DexterSpacing.lg)
                .padding(.bottom, DexterSpacing.xxl)
            }
        }
        .background(DexterSurfaceColors.background)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(profile.name) profile")
    }

    private func headerToolbar(profile: DexterProfile) -> some View {
        HStack(spacing: DexterSpacing.sm) {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DexterColors.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(DexterSurfaceColors.surface)
                    )
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityLabel("Close profile")

            Spacer(minLength: 0)
            Menu {
                Button("Edit character") { onEditCharacter(profile) }
                Button("Integrations") { openIntegrationsSettings() }
            } label: {
                headerActionLabel(title: "More")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("More actions for \(profile.name)")
        }
        .padding(.horizontal, DexterSpacing.lg)
        .padding(.vertical, DexterSpacing.md)
    }

    private func profileHeroBand(profile: DexterProfile) -> some View {
        VStack(spacing: DexterSpacing.lg) {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        profile.accentColor.opacity(0.22),
                        profile.accentColor.opacity(0.06),
                        DexterSurfaceColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)

                DexterCharacterStagePortrait(
                    profile: profile,
                    characterState: resolvedCharacterState(for: profile),
                    height: 250,
                    animationEnabled: isRepresentingActiveWorkspace(profile: profile)
                )
                .padding(.top, DexterSpacing.md)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous))

            VStack(spacing: DexterSpacing.sm) {
                Text(profile.name)
                    .font(DexterTypography.display())
                    .foregroundColor(DexterSurfaceColors.textPrimary)

                Text(profile.displayRole)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(profile.accentColor)

                if let tagline = profileTagline(profile: profile) {
                    Text(tagline)
                        .font(DexterTypography.secondary())
                        .foregroundColor(DexterColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DexterSpacing.sm)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            HStack(spacing: DexterSpacing.sm) {
                profileHeroPillButton(title: "Edit character", isPrimary: false) {
                    onEditCharacter(profile)
                }
                profileHeroPillButton(title: "Chat", isPrimary: true, accent: profile.accentColor) {
                    onChat()
                    onDismiss()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let status = activeStatusLabel(for: profile) {
                HStack(spacing: DexterSpacing.xs) {
                    Circle()
                        .fill(profile.accentColor)
                        .frame(width: 6, height: 6)
                    Text(status)
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                }
            }
        }
        .padding(.top, DexterSpacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func profileHeroPillButton(
        title: String,
        isPrimary: Bool,
        accent: Color = DexterPastelColors.lavender,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(isPrimary ? DexterColors.textPrimary : DexterColors.textSecondary)
                .padding(.horizontal, DexterSpacing.lg)
                .padding(.vertical, DexterSpacing.sm + 2)
                .background {
                    Capsule(style: .continuous)
                        .fill(
                            isPrimary
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [accent.opacity(0.45), DexterPastelColors.sky.opacity(0.35)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                : AnyShapeStyle(DexterSurfaceColors.surfaceElevated)
                        )
                }
        }
        .buttonStyle(DexterTactileButtonStyle())
        .pointerCursor()
    }

    private func aboutSection(profile: DexterProfile) -> some View {
        profileSection(title: "ABOUT") {
            Text(aboutNarrative(for: profile))
                .font(DexterTypography.body())
                .foregroundColor(DexterSurfaceColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let characterName = characterDefinition(for: profile)?.displayName {
                HStack(spacing: DexterSpacing.sm) {
                    Circle()
                        .fill(profile.accentColor.opacity(0.25))
                        .frame(width: 8, height: 8)
                    Text("Character · \(characterName)")
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                }
            }
        }
    }

    private func aboutNarrative(for profile: DexterProfile) -> String {
        if let description = trimmedDescription(profile.description), !description.isEmpty {
            return description
        }
        return "\(profile.name) helps with \(profile.displayRole.lowercased())."
    }

    private func memorySection(profile: DexterProfile) -> some View {
        let profileMemories = companionManager.structuredMemories(forProfileId: profile.id)
        let savedCount = profileMemories.count
        let lastUpdated = profileMemories.map(\.updatedAt).max()
        let mostRecentContent = profileMemories.first?.userFacingSummary

        return profileSection(title: "THINGS I REMEMBER") {
            if savedCount == 0 {
                Text("No saved memories yet.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                Text("Tell Dexter something you'd like it to remember.")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            } else {
                Text("\(savedCount) saved memor\(savedCount == 1 ? "y" : "ies")")
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                if let mostRecentContent {
                    Text("Most recent: “\(mostRecentContent)”")
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textSecondary)
                        .lineLimit(2)
                }
                if let lastUpdated {
                    Text("Last updated \(Self.relativeFormatter.localizedString(for: lastUpdated, relativeTo: Date()))")
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                }
            }

            Text(memoryPrivacyLine(for: profile))
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button("View memory") {
                isMemoryDetailPresented = true
            }
            .buttonStyle(.plain)
            .font(DexterTypography.bodyMedium())
            .foregroundColor(profile.accentColor)
            .pointerCursor()
            .accessibilityLabel("\(profile.name) memory")
        }
    }

    private func skillsSection(profile: DexterProfile) -> some View {
        let availableSkills = companionManager.dexterProductCapabilities.filter {
            $0.isSkillHighlight && $0.availability == .available
        }
        return profileSection(title: "SKILLS") {
            if availableSkills.isEmpty {
                Text("No capabilities are available on this Mac yet. Check Settings → Capabilities.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                    ForEach(availableSkills) { capability in
                        Button {
                            selectedProductCapability = capability
                        } label: {
                            HStack(spacing: DexterSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(profile.accentColor.opacity(0.9))
                                Text(capability.displayName)
                                    .font(DexterTypography.bodyMedium())
                                    .foregroundColor(DexterSurfaceColors.textPrimary)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .pointerCursor()
                        .accessibilityLabel("\(capability.displayName), available")
                    }
                }
            }
        }
    }

    private func integrationsSection(profile: DexterProfile) -> some View {
        let integrations = profileOperationalIntegrations(for: profile)
        return profileSection(title: "INTEGRATIONS") {
            if integrations.isEmpty {
                Text("Connect the tools you use to give this Dexter more context and capabilities.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Connect") {
                    openIntegrationsSettings()
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(profile.accentColor)
                .pointerCursor()
            } else {
                VStack(spacing: DexterSpacing.sm) {
                    ForEach(integrations) { integration in
                        DexterIntegrationCard(
                            integration: integration,
                            onPrimaryAction: {
                                handleIntegrationPrimaryAction(integration)
                            },
                            onManage: integration.id == "github" ? { openIntegrationsSettings() } : nil
                        )
                    }
                }
            }
        }
    }

    private func profileOperationalIntegrations(for profile: DexterProfile) -> [DexterIntegration] {
        let operational = companionManager.dexterIntegrationService.integrations.filter { $0.kind == .operational }
        let linkedIDs = Set(profile.connectedIntegrations)
        let linked = operational.filter { linkedIDs.contains($0.id) }
        if !linked.isEmpty {
            return linked
        }
        return operational.filter { $0.connectionState == .connected }
    }

    private func handleIntegrationPrimaryAction(_ integration: DexterIntegration) {
        openIntegrationsSettings()
    }

    private func routinesSection(profile: DexterProfile) -> some View {
        let routines = companionManager.dexterRoutineStore.routines(forProfileId: profile.id)
        let activeCount = routines.filter { $0.isEnabled && $0.status == .active }.count

        return profileSection(title: "ROUTINES") {
            if routines.isEmpty {
                VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                    Text("No routines yet.")
                        .font(DexterTypography.secondary())
                        .foregroundColor(DexterColors.textSecondary)
                    Text("Give me something you want me to handle automatically.")
                        .font(DexterTypography.caption())
                        .foregroundColor(DexterColors.textTertiary)
                    Button("Create routine") {
                        presentRoutineCreation(for: profile)
                    }
                    .buttonStyle(.plain)
                    .font(DexterTypography.bodyMedium())
                    .foregroundColor(profile.accentColor)
                    .pointerCursor()
                }
            } else {
                Text("\(activeCount) active routine\(activeCount == 1 ? "" : "s")")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)

                ForEach(routines.prefix(3)) { routine in
                    DexterRoutineCard(
                        routine: routine,
                        profile: profile,
                        characterState: routine.status == .failed ? .error : .idle,
                        onToggleEnabled: { isEnabled in
                            companionManager.dexterRoutineStore.setEnabled(routineId: routine.id, isEnabled: isEnabled)
                        },
                        onOpenDetails: { selectedRoutineId = routine.id },
                        onRunNow: {
                            companionManager.runDexterRoutine(routineID: routine.id, runKind: .manual)
                        }
                    )
                }

                Button("Create routine") {
                    presentRoutineCreation(for: profile)
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(profile.accentColor)
                .pointerCursor()
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedRoutineId != nil },
            set: { isPresented in
                if !isPresented { selectedRoutineId = nil }
            }
        )) {
            if let routineId = selectedRoutineId {
                DexterRoutineDetailView(
                    companionManager: companionManager,
                    routineId: routineId,
                    onDismiss: { selectedRoutineId = nil }
                )
            }
        }
        .sheet(isPresented: $isRoutineCreatePresented) {
            if let draft = companionManager.dexterRoutineStore.pendingCreationDraft {
                DexterRoutineCreateFlowView(
                    companionManager: companionManager,
                    routineStore: companionManager.dexterRoutineStore,
                    onDismiss: { isRoutineCreatePresented = false }
                )
            }
        }
    }

    private func presentRoutineCreation(for profile: DexterProfile) {
        let draft = DexterRoutineCreationDraft(
            naturalLanguageInput: "",
            name: "",
            instruction: "",
            description: "",
            trigger: DexterRoutineTrigger(kind: .manualOnly),
            dexterProfileId: profile.id,
            requiredCapabilityIDs: []
        )
        companionManager.dexterRoutineStore.presentCreationDraft(draft)
        isRoutineCreatePresented = true
    }

    private func permissionsSection(profile: DexterProfile) -> some View {
        profileSection(title: "PERMISSIONS") {
            permissionRow(title: "Screen context", detail: screenContextPermissionLabel)
            permissionRow(title: "Microphone", detail: microphonePermissionLabel)
            permissionRow(title: "Computer control", detail: computerControlPermissionLabel(profile: profile))
        }
    }

    private func activitySection(profile: DexterProfile) -> some View {
        let items = companionManager.dexterActivityRecorder.recentEvents(
            forProfileId: profile.id,
            includeGlobal: true,
            limit: 4
        )
        return profileSection(title: "ACTIVITY") {
            if items.isEmpty {
                Text("No activity yet.")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: DexterSpacing.sm) {
                    ForEach(items) { record in
                        DexterActivityRow(record: record)
                    }
                }
                Button("View all") {
                    isActivityDetailPresented = true
                }
                .buttonStyle(.plain)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(profile.accentColor)
                .pointerCursor()
            }
        }
    }

    // MARK: - Building blocks

    private func profileSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            Text(title)
                .font(DexterTypography.section())
                .foregroundColor(DexterColors.textTertiary)
            content()
        }
        .padding(DexterSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                .fill(DexterSurfaceColors.surfaceElevated.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DexterRadii.card, style: .continuous)
                .stroke(DexterSurfaceColors.border.opacity(0.35), lineWidth: 1)
        )
    }

    private func aboutRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
            Text(value)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterSurfaceColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func permissionRow(title: String, detail: String) -> some View {
        HStack {
            Text(title)
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterSurfaceColors.textPrimary)
            Spacer(minLength: 0)
            Text(detail)
                .font(DexterTypography.caption())
                .foregroundColor(DexterColors.textTertiary)
        }
    }

    private func headerActionButton(title: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            headerActionLabel(title: title)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .accessibilityLabel(accessibilityLabel)
    }

    private func headerActionLabel(title: String) -> some View {
        Text(title)
            .font(DexterTypography.bodyMedium())
            .foregroundColor(DexterColors.textSecondary)
            .padding(.horizontal, DexterSpacing.sm)
            .padding(.vertical, DexterSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DexterRadii.small, style: .continuous)
                    .fill(DexterSurfaceColors.surface)
            )
    }

    private var missingProfilePlaceholder: some View {
        VStack(spacing: DexterSpacing.md) {
            Text("This Dexter is no longer available.")
                .font(DexterTypography.body())
                .foregroundColor(DexterColors.textSecondary)
            Button("Close", action: onDismiss)
                .pointerCursor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data resolution

    private func characterDefinition(for profile: DexterProfile) -> DexterCharacterDefinition? {
        DexterCharacterCatalog.character(withID: profile.characterAppearance.characterID)
            ?? DexterCharacterCatalog.character(
                withID: DexterCharacterCatalog.defaultCharacterID(forProfileID: profile.id)
            )
    }

    private func resolvedCharacterState(for profile: DexterProfile) -> DexterCharacterState {
        guard isRepresentingActiveWorkspace(profile: profile) else { return .idle }
        return companionManager.activeCharacterState
    }

    private func isRepresentingActiveWorkspace(profile: DexterProfile) -> Bool {
        switch companionManager.homeWorkspacePresentation {
        case .dashboard:
            return companionManager.dexterProfileStore.activeProfileId == profile.id
        case .dexterWorkspace(let profileId):
            return profileId == profile.id
        }
    }

    private func profileTagline(profile: DexterProfile) -> String? {
        let purpose = profile.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = profile.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty, description != purpose {
            return description
        }
        if !purpose.isEmpty, purpose != profile.displayRole {
            return purpose
        }
        return nil
    }

    private func trimmedDescription(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func memoryPrivacyLine(for profile: DexterProfile) -> String {
        switch profile.memoryScope {
        case .isolated:
            return "Saved memories stay with this Dexter's workspace — not everything on your Mac."
        case .shared:
            return "This Dexter can use shared memories across your workspace."
        }
    }

    private var screenContextPermissionLabel: String {
        if companionManager.hasScreenRecordingPermission && companionManager.hasScreenContentPermission {
            return "Allowed"
        }
        if companionManager.hasScreenRecordingPermission {
            return "Screen on · context needs approval"
        }
        return "Not allowed"
    }

    private var microphonePermissionLabel: String {
        companionManager.hasMicrophonePermission ? "Allowed" : "Not allowed"
    }

    private func computerControlPermissionLabel(profile: DexterProfile) -> String {
        if !profile.permissions.allowsComputerActions {
            return "Off for this Dexter"
        }
        if companionManager.autoApproveLowRiskActions {
            return "Low-risk actions auto-approved"
        }
        return "Ask each time"
    }

    private func activeStatusLabel(for profile: DexterProfile) -> String? {
        guard isRepresentingActiveWorkspace(profile: profile) else { return nil }
        switch companionManager.voiceInteractionState {
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .speaking:
            return "Speaking"
        case .error:
            return "Voice issue"
        case .idle:
            break
        }
        switch companionManager.dexterRuntimeUIStateStore.currentState {
        case .idle, .done, .cancelled:
            return nil
        case .listening:
            return "Listening"
        case .understanding:
            return "Understanding"
        case .thinking, .planning:
            return "Working"
        case .waitingPermission:
            return "Waiting for permission"
        case .acting:
            return "Working"
        case .verifying:
            return "Verifying"
        case .failed:
            return "Something went wrong"
        }
    }

    private func loadIntegrationsIfNeeded() {
        guard !didLoadIntegrations else { return }
        didLoadIntegrations = true
        companionManager.refreshDexterIntegrations()
    }

    private func openIntegrationsSettings() {
        NotificationCenter.default.post(name: .dexterOpenMainWindowSettings, object: nil)
    }
}

private struct DexterProfileSkillChipFlow: View {
    let labels: [String]
    let accentColor: Color

    var body: some View {
        FlowLayout(spacing: DexterSpacing.xs) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
                    .padding(.horizontal, DexterSpacing.sm)
                    .padding(.vertical, DexterSpacing.xs)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.18))
                    )
            }
        }
    }
}

/// Simple horizontal wrapping layout for skill chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for placement in result.placements {
            subviews[placement.index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: .unspecified
            )
        }
    }

    private struct Placement {
        let index: Int
        let x: CGFloat
        let y: CGFloat
    }

    private struct ArrangeResult {
        let size: CGSize
        let placements: [Placement]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var placements: [Placement] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            placements.append(Placement(index: index, x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        let totalHeight = y + rowHeight
        return ArrangeResult(size: CGSize(width: maxWidth, height: totalHeight), placements: placements)
    }
}

private extension DexterProactiveEventKind {
    var profileRoutineTitle: String {
        switch self {
        case .taskDeadlineApproaching:
            return "Deadline reminders"
        case .newFile:
            return "New file awareness"
        case .workflowRepetition:
            return "Repeated workflow assist"
        case .applicationState:
            return "Application state"
        case .calendarEvent:
            return "Calendar events"
        }
    }
}
