//
//  DexterRoutineModels.swift
//  leanring-buddy
//

import Foundation

enum DexterRoutineStatus: String, Codable, Equatable, CaseIterable {
    case active
    case paused
    case completed
    case failed

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

enum DexterRoutineTriggerKind: String, Codable, Equatable {
    case schedule
    case applicationOpened
    case manualOnly
    case taskCompletion

    var isSupportedForAutomaticExecution: Bool {
        switch self {
        case .schedule, .applicationOpened:
            return true
        case .manualOnly, .taskCompletion:
            return false
        }
    }
}

enum DexterRoutineScheduleFrequency: String, Codable, Equatable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case daily
    case weekly

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

struct DexterRoutineSchedule: Codable, Equatable {
    var frequency: DexterRoutineScheduleFrequency
    /// 1 = Sunday … 7 = Saturday (Calendar.current)
    var weekday: Int?
    var hour: Int
    var minute: Int
    var timeZoneIdentifier: String

    static func defaultMorning(hour: Int = 8, minute: Int = 0) -> DexterRoutineSchedule {
        DexterRoutineSchedule(
            frequency: .daily,
            weekday: nil,
            hour: hour,
            minute: minute,
            timeZoneIdentifier: TimeZone.current.identifier
        )
    }

    func summaryLabel(calendar: Calendar = .current) -> String {
        let timeString = Self.formatTime(hour: hour, minute: minute, calendar: calendar)
        switch frequency {
        case .daily:
            return "Every day · \(timeString)"
        case .weekly:
            let weekdaySymbol = weekday.flatMap { calendar.weekdaySymbols[safe: $0 - 1] } ?? "Weekday"
            return "Every \(weekdaySymbol) · \(timeString)"
        }
    }

    func computeNextRunDate(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        switch frequency {
        case .daily:
            guard let candidate = calendar.date(from: components) else { return nil }
            if candidate > referenceDate {
                return candidate
            }
            return calendar.date(byAdding: .day, value: 1, to: candidate)
        case .weekly:
            guard let targetWeekday = weekday else { return nil }
            components.weekday = targetWeekday
            guard let candidate = calendar.nextDate(
                after: referenceDate,
                matching: components,
                matchingPolicy: .nextTime
            ) else { return nil }
            if candidate > referenceDate {
                return candidate
            }
            return calendar.date(byAdding: .weekOfYear, value: 1, to: candidate)
        }
    }

    private static func formatTime(hour: Int, minute: Int, calendar: Calendar) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
}

struct DexterRoutineTrigger: Codable, Equatable {
    var kind: DexterRoutineTriggerKind
    var schedule: DexterRoutineSchedule?
    var applicationBundleIdentifier: String?
    var applicationDisplayName: String?
    var taskCompletionDescription: String?

    var summaryLabel: String {
        switch kind {
        case .schedule:
            return schedule?.summaryLabel() ?? "Scheduled"
        case .applicationOpened:
            let name = applicationDisplayName ?? applicationBundleIdentifier ?? "App"
            return "When \(name) opens"
        case .manualOnly:
            return "Manual only"
        case .taskCompletion:
            return taskCompletionDescription ?? "After task completes"
        }
    }

    func asAutomationTrigger(instruction: String) -> DexterAutomationTrigger {
        switch kind {
        case .schedule:
            let description = schedule?.summaryLabel() ?? "scheduled routine"
            return .scheduled(description: "\(description): \(instruction)")
        case .applicationOpened:
            return .context(conditionDescription: "application_opened:\(applicationBundleIdentifier ?? "unknown")")
        case .manualOnly, .taskCompletion:
            return .manualInvocation(userMessage: instruction)
        }
    }
}

struct DexterRoutineRunRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let completedAt: Date?
    let succeeded: Bool
    let summary: String

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        succeeded: Bool,
        summary: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.succeeded = succeeded
        self.summary = summary
    }
}

struct DexterRoutine: Identifiable, Codable, Equatable {
    let id: UUID
    var dexterProfileId: UUID
    var name: String
    var description: String
    var instruction: String
    var trigger: DexterRoutineTrigger
    var status: DexterRoutineStatus
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date
    var lastRunAt: Date?
    var nextRunAt: Date?
    var requiredCapabilityIDs: [DexterProductCapabilityID]
    var runHistory: [DexterRoutineRunRecord]
    var lastFailureReason: String?

    var isRunnable: Bool {
        isEnabled && status != .paused && status != .completed
    }

    init(
        id: UUID = UUID(),
        dexterProfileId: UUID,
        name: String,
        description: String,
        instruction: String,
        trigger: DexterRoutineTrigger,
        status: DexterRoutineStatus = .active,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastRunAt: Date? = nil,
        nextRunAt: Date? = nil,
        requiredCapabilityIDs: [DexterProductCapabilityID] = [],
        runHistory: [DexterRoutineRunRecord] = [],
        lastFailureReason: String? = nil
    ) {
        self.id = id
        self.dexterProfileId = dexterProfileId
        self.name = name
        self.description = description
        self.instruction = instruction
        self.trigger = trigger
        self.status = status
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.requiredCapabilityIDs = requiredCapabilityIDs
        self.runHistory = runHistory
        self.lastFailureReason = lastFailureReason
    }
}

struct DexterRoutineCreationDraft: Equatable {
    var naturalLanguageInput: String
    var name: String
    var instruction: String
    var description: String
    var trigger: DexterRoutineTrigger
    var dexterProfileId: UUID
    var requiredCapabilityIDs: [DexterProductCapabilityID]
    var missingScheduleDetailPrompt: String?

    var isReadyForPreview: Bool {
        missingScheduleDetailPrompt == nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum DexterRoutineAmbientAnnouncement: Equatable {
    case success(routineName: String, detail: String)
    case failure(routineName: String, reason: String)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
