//
//  DexterRoutineCreateFlowView.swift
//  leanring-buddy
//

import SwiftUI

struct DexterRoutineCreateFlowView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var routineStore: DexterRoutineStore
    var onDismiss: () -> Void

    @State private var step: CreateStep = .compose
    @State private var scheduleFrequency: DexterRoutineScheduleFrequency = .daily
    @State private var scheduleHour: Int = 8
    @State private var scheduleMinute: Int = 0
    @State private var scheduleWeekday: Int = 2

    private enum CreateStep {
        case compose
        case preview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.lg) {
            Text(step == .compose ? "Create routine" : "Create routine")
                .font(DexterTypography.title())
                .foregroundColor(DexterSurfaceColors.textPrimary)

            if step == .compose {
                composeStep
            } else {
                previewStep
            }
        }
        .padding(DexterSpacing.lg)
        .frame(minWidth: 440, minHeight: 420)
        .background(DexterSurfaceColors.background)
        .onAppear {
            syncScheduleControlsFromDraft()
        }
    }

    private var composeStep: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            Text("What should I do for you?")
                .font(DexterTypography.bodyMedium())
                .foregroundColor(DexterColors.textSecondary)

            TextField("Every morning at 8, make me a study plan.", text: naturalLanguageBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(DexterSurfaceColors.surfaceElevated.opacity(0.5)))
                .onSubmit { applyNaturalLanguageParse() }

            if draft.trigger.kind == .schedule {
                scheduleControls
            }

            if draft.trigger.kind == .taskCompletion {
                Text("Task completion triggers are coming soon.")
                    .font(DexterTypography.caption())
                    .foregroundColor(.orange)
            }

            if let prompt = draft.missingScheduleDetailPrompt {
                Text(prompt)
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterPastelColors.lavender)
            }

            capabilitySummary

            HStack {
                Spacer()
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.plain)
                    .pointerCursor()
                Button("Continue") {
                    applyNaturalLanguageParse()
                    if draft.isReadyForPreview {
                        step = .preview
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DexterPastelColors.lavender)
                .pointerCursor()
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: DexterSpacing.md) {
            Text(draft.name)
                .font(DexterTypography.title())
            Text(draft.trigger.summaryLabel)
                .font(DexterTypography.secondary())
                .foregroundColor(DexterColors.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Action")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
                Text("\"\(draft.instruction)\"")
                    .font(DexterTypography.body())
                    .foregroundColor(DexterSurfaceColors.textPrimary)
            }

            if let profile = companionManager.dexterProfileStore.profile(withId: draft.dexterProfileId) {
                Text("Dexter: \(profile.name)")
                    .font(DexterTypography.secondary())
                    .foregroundColor(DexterColors.textSecondary)
            }

            capabilitySummary

            HStack {
                Button("Edit") { step = .compose }
                    .buttonStyle(.plain)
                    .pointerCursor()
                Spacer()
                Button("Create routine") {
                    guard let draft = routineStore.pendingCreationDraft else { return }
                    _ = routineStore.createRoutine(from: draft)
                    routineStore.isCreateFlowPresented = false
                    routineStore.pendingCreationDraft = nil
                    onDismiss()
                    NotificationCenter.default.post(name: .dexterOpenMainWindow, object: nil)
                }
                .buttonStyle(.borderedProminent)
                .tint(DexterPastelColors.lavender)
                .pointerCursor()
            }
        }
    }

    private var scheduleControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Frequency", selection: $scheduleFrequency) {
                ForEach(DexterRoutineScheduleFrequency.allCases) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: scheduleFrequency) { _, _ in applyScheduleToDraft() }

            if scheduleFrequency == .weekly {
                Picker("Weekday", selection: $scheduleWeekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                    }
                }
                .onChange(of: scheduleWeekday) { _, _ in applyScheduleToDraft() }
            }

            HStack {
                Stepper("Hour: \(scheduleHour)", value: $scheduleHour, in: 0...23)
                    .onChange(of: scheduleHour) { _, _ in applyScheduleToDraft() }
                Stepper("Minute: \(scheduleMinute)", value: $scheduleMinute, in: 0...59, step: 5)
                    .onChange(of: scheduleMinute) { _, _ in applyScheduleToDraft() }
            }
            .font(DexterTypography.caption())
        }
    }

    private var capabilitySummary: some View {
        let unavailable = DexterRoutineCapabilityResolver.unavailableCapabilityLabels(
            requiredCapabilityIDs: draft.requiredCapabilityIDs,
            availableCapabilities: companionManager.dexterProductCapabilities
        )
        return VStack(alignment: .leading, spacing: 4) {
            if !draft.requiredCapabilityIDs.isEmpty {
                Text("Requires: \(draft.requiredCapabilityIDs.map(\.rawValue).joined(separator: ", "))")
                    .font(DexterTypography.caption())
                    .foregroundColor(DexterColors.textTertiary)
            }
            if !unavailable.isEmpty {
                Text("\(unavailable.joined(separator: ", ")) connection required.")
                    .font(DexterTypography.caption())
                    .foregroundColor(.orange)
            }
        }
    }

    private var naturalLanguageBinding: Binding<String> {
        Binding(
            get: { routineStore.pendingCreationDraft?.naturalLanguageInput ?? "" },
            set: { newValue in
                guard var draft = routineStore.pendingCreationDraft else { return }
                draft.naturalLanguageInput = newValue
                routineStore.pendingCreationDraft = draft
            }
        )
    }

    private var draft: DexterRoutineCreationDraft {
        routineStore.pendingCreationDraft ?? DexterRoutineCreationDraft(
            naturalLanguageInput: "",
            name: "",
            instruction: "",
            description: "",
            trigger: DexterRoutineTrigger(kind: .manualOnly),
            dexterProfileId: companionManager.dexterProfileStore.activeProfileId ?? UUID(),
            requiredCapabilityIDs: []
        )
    }

    private func applyNaturalLanguageParse() {
        let profileId = companionManager.dexterProfileStore.activeProfileId ?? draft.dexterProfileId
        var parsed = DexterRoutineNaturalLanguageParser.parseCreationDraft(
            input: draft.naturalLanguageInput,
            defaultDexterProfileId: profileId
        )
        if draft.trigger.kind == .schedule {
            parsed.trigger = draft.trigger
        }
        routineStore.pendingCreationDraft = parsed
        syncScheduleControlsFromDraft()
    }

    private func syncScheduleControlsFromDraft() {
        guard let schedule = draft.trigger.schedule else { return }
        scheduleFrequency = schedule.frequency
        scheduleHour = schedule.hour
        scheduleMinute = schedule.minute
        scheduleWeekday = schedule.weekday ?? 2
    }

    private func applyScheduleToDraft() {
        guard var updatedDraft = routineStore.pendingCreationDraft else { return }
        updatedDraft.trigger = DexterRoutineTrigger(
            kind: .schedule,
            schedule: DexterRoutineSchedule(
                frequency: scheduleFrequency,
                weekday: scheduleFrequency == .weekly ? scheduleWeekday : nil,
                hour: scheduleHour,
                minute: scheduleMinute,
                timeZoneIdentifier: TimeZone.current.identifier
            )
        )
        updatedDraft.missingScheduleDetailPrompt = nil
        routineStore.pendingCreationDraft = updatedDraft
    }
}
