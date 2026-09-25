//
//  DexterRoutineStore.swift
//  leanring-buddy
//

import Combine
import Foundation

@MainActor
final class DexterRoutineStore: ObservableObject {
    weak var activityRecorder: DexterActivityRecorder?
    @Published private(set) var routines: [DexterRoutine] = []
    @Published var pendingCreationDraft: DexterRoutineCreationDraft?
    @Published var isCreateFlowPresented = false
    @Published private(set) var ambientAnnouncement: DexterRoutineAmbientAnnouncement?

    private let fileURL: URL
    private let maxRunHistoryCount = 20

    init(fileURL: URL? = nil) {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dexterDirectory = supportDirectory.appendingPathComponent("Dexter", isDirectory: true)
        self.fileURL = fileURL ?? dexterDirectory.appendingPathComponent("dexter-routines.json")
        loadFromDisk()
    }

    func routines(forProfileId profileId: UUID) -> [DexterRoutine] {
        routines.filter { $0.dexterProfileId == profileId }
    }

    func routine(withId routineId: UUID) -> DexterRoutine? {
        routines.first { $0.id == routineId }
    }

    func activeRoutines(forProfileId profileId: UUID) -> [DexterRoutine] {
        routines(forProfileId: profileId).filter { $0.isEnabled && $0.status == .active }
    }

    @discardableResult
    func upsertRoutine(_ routine: DexterRoutine) -> DexterRoutine {
        var updatedRoutine = routine
        updatedRoutine.updatedAt = Date()
        updatedRoutine.nextRunAt = DexterRoutineDueDateEvaluator.nextRunDate(for: updatedRoutine)

        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = updatedRoutine
        } else {
            routines.append(updatedRoutine)
        }
        saveToDisk()
        return updatedRoutine
    }

    func deleteRoutine(id: UUID) {
        routines.removeAll { $0.id == id }
        saveToDisk()
    }

    func setEnabled(routineId: UUID, isEnabled: Bool) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].isEnabled = isEnabled
        routines[index].updatedAt = Date()
        if isEnabled && routines[index].status == .paused {
            routines[index].status = .active
        }
        routines[index].nextRunAt = DexterRoutineDueDateEvaluator.nextRunDate(for: routines[index])
        saveToDisk()
    }

    func setPaused(routineId: UUID, isPaused: Bool) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        routines[index].status = isPaused ? .paused : .active
        routines[index].updatedAt = Date()
        routines[index].nextRunAt = DexterRoutineDueDateEvaluator.nextRunDate(for: routines[index])
        saveToDisk()
    }

    func recordRunOutcome(
        routineId: UUID,
        startedAt: Date,
        succeeded: Bool,
        summary: String
    ) {
        guard let index = routines.firstIndex(where: { $0.id == routineId }) else { return }
        let record = DexterRoutineRunRecord(
            startedAt: startedAt,
            completedAt: Date(),
            succeeded: succeeded,
            summary: summary
        )
        routines[index].runHistory.insert(record, at: 0)
        if routines[index].runHistory.count > maxRunHistoryCount {
            routines[index].runHistory = Array(routines[index].runHistory.prefix(maxRunHistoryCount))
        }
        routines[index].lastRunAt = record.completedAt
        routines[index].status = succeeded ? .active : .failed
        routines[index].lastFailureReason = succeeded ? nil : summary
        routines[index].nextRunAt = DexterRoutineDueDateEvaluator.nextRunDate(for: routines[index])
        routines[index].updatedAt = Date()
        saveToDisk()

        let routine = routines[index]
        let routineName = routine.name
        activityRecorder?.recordRoutineRun(
            routine: routine,
            startedAt: startedAt,
            succeeded: succeeded,
            summary: summary
        )
        ambientAnnouncement = succeeded
            ? .success(routineName: routineName, detail: summary)
            : .failure(routineName: routineName, reason: summary)
    }

    func clearAmbientAnnouncement() {
        ambientAnnouncement = nil
    }

    func presentCreationDraft(_ draft: DexterRoutineCreationDraft) {
        pendingCreationDraft = draft
        isCreateFlowPresented = true
    }

    func createRoutine(from draft: DexterRoutineCreationDraft) -> DexterRoutine {
        let prototype = DexterRoutine(
            dexterProfileId: draft.dexterProfileId,
            name: draft.name,
            description: draft.description,
            instruction: draft.instruction,
            trigger: draft.trigger,
            requiredCapabilityIDs: draft.requiredCapabilityIDs
        )
        let routine = DexterRoutine(
            dexterProfileId: draft.dexterProfileId,
            name: draft.name,
            description: draft.description,
            instruction: draft.instruction,
            trigger: draft.trigger,
            nextRunAt: DexterRoutineDueDateEvaluator.nextRunDate(for: prototype),
            requiredCapabilityIDs: draft.requiredCapabilityIDs
        )
        return upsertRoutine(routine)
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            routines = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            routines = try decoder.decode([DexterRoutine].self, from: data)
        } catch {
            print("⚠️ Dexter routines load failed: \(error)")
            routines = []
        }
    }

    private func saveToDisk() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(routines)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("⚠️ Dexter routines save failed: \(error)")
        }
    }
}

enum DexterRoutineDueDateEvaluator {
    static func nextRunDate(for routine: DexterRoutine, from date: Date = Date()) -> Date? {
        guard routine.isEnabled, routine.status == .active else { return nil }
        guard routine.trigger.kind == .schedule, let schedule = routine.trigger.schedule else { return nil }
        return schedule.computeNextRunDate(from: date)
    }

    static func isRoutineDue(_ routine: DexterRoutine, at date: Date = Date()) -> Bool {
        guard let nextRunAt = routine.nextRunAt else { return false }
        return nextRunAt <= date
    }
}
