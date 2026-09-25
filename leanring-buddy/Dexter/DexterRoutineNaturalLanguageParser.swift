//
//  DexterRoutineNaturalLanguageParser.swift
//  leanring-buddy
//

import Foundation

enum DexterRoutineNaturalLanguageParser {
    static func parseCreationDraft(
        input: String,
        defaultDexterProfileId: UUID
    ) -> DexterRoutineCreationDraft {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        var draft = DexterRoutineCreationDraft(
            naturalLanguageInput: trimmed,
            name: "",
            instruction: trimmed,
            description: "",
            trigger: DexterRoutineTrigger(kind: .manualOnly, schedule: nil),
            dexterProfileId: defaultDexterProfileId,
            requiredCapabilityIDs: [],
            missingScheduleDetailPrompt: nil
        )

        draft.name = inferredName(from: normalized, original: trimmed)
        draft.instruction = inferredInstruction(from: trimmed, normalized: normalized)
        draft.description = draft.instruction

        if let applicationTrigger = parseApplicationOpenedTrigger(normalized: normalized) {
            draft.trigger = applicationTrigger
        } else if normalized.contains("after this finishes") || normalized.contains("after it finishes") {
            draft.trigger = DexterRoutineTrigger(
                kind: .taskCompletion,
                taskCompletionDescription: "After linked task completes"
            )
            draft.missingScheduleDetailPrompt = "Task-completion routines are not available yet. Use Run now or a schedule instead."
        } else if let schedule = parseSchedule(normalized: normalized) {
            draft.trigger = DexterRoutineTrigger(kind: .schedule, schedule: schedule)
            if schedule.frequency == .daily && !normalized.contains("at ") && !normalized.contains(":") {
                draft.missingScheduleDetailPrompt = "What time should I run it?"
            }
        } else if normalized.contains("every morning") || normalized.contains("every evening") {
            let hour = normalized.contains("evening") ? 18 : 8
            draft.trigger = DexterRoutineTrigger(
                kind: .schedule,
                schedule: DexterRoutineSchedule.defaultMorning(hour: hour, minute: 0)
            )
        } else if normalized.contains("every ") {
            draft.missingScheduleDetailPrompt = "What time should I run it?"
            draft.trigger = DexterRoutineTrigger(kind: .schedule, schedule: DexterRoutineSchedule.defaultMorning())
        }

        draft.requiredCapabilityIDs = DexterRoutineCapabilityResolver.requiredCapabilities(
            forInstruction: draft.instruction
        )

        return draft
    }

    private static func inferredName(from normalized: String, original: String) -> String {
        if normalized.contains("study plan") { return "Morning Study Plan" }
        if normalized.contains("github") { return "GitHub Review" }
        if normalized.contains("remind") { return "Daily Reminder" }
        if normalized.contains("review") { return "Daily Review" }
        let words = original.split(separator: " ").prefix(4).joined(separator: " ")
        return words.isEmpty ? "New Routine" : words
    }

    private static func inferredInstruction(from original: String, normalized: String) -> String {
        var instruction = original
        let prefixes = [
            "every morning at ",
            "every morning ",
            "every day at ",
            "every day ",
            "every monday at ",
            "every monday ",
            "every evening at ",
            "every evening ",
            "when i open ",
            "when i launch "
        ]
        for prefix in prefixes {
            if let range = normalized.range(of: prefix) {
                let offset = normalized.distance(from: normalized.startIndex, to: range.upperBound)
                if offset < instruction.count {
                    let index = instruction.index(instruction.startIndex, offsetBy: offset)
                    instruction = String(instruction[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        if instruction.isEmpty { return original }
        return instruction
    }

    private static func parseSchedule(normalized: String) -> DexterRoutineSchedule? {
        guard normalized.contains("every ") else { return nil }

        let time = parseTime(from: normalized) ?? (8, 0)
        let weekdays: [(String, Int)] = [
            ("monday", 2), ("tuesday", 3), ("wednesday", 4), ("thursday", 5),
            ("friday", 6), ("saturday", 7), ("sunday", 1)
        ]
        for (label, weekday) in weekdays where normalized.contains("every \(label)") {
            return DexterRoutineSchedule(
                frequency: .weekly,
                weekday: weekday,
                hour: time.hour,
                minute: time.minute,
                timeZoneIdentifier: TimeZone.current.identifier
            )
        }

        if normalized.contains("every day")
            || normalized.contains("every morning")
            || normalized.contains("every evening") {
            return DexterRoutineSchedule(
                frequency: .daily,
                weekday: nil,
                hour: time.hour,
                minute: time.minute,
                timeZoneIdentifier: TimeZone.current.identifier
            )
        }
        return nil
    }

    private static func parseTime(from normalized: String) -> (hour: Int, minute: Int)? {
        let patterns = [
            #"at (\d{1,2}):(\d{2})\s*(am|pm)?"#,
            #"at (\d{1,2})\s*(am|pm)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(normalized.startIndex..., in: normalized)
            guard let match = regex.firstMatch(in: normalized, range: range) else { continue }
            if match.numberOfRanges >= 2,
               let hourRange = Range(match.range(at: 1), in: normalized),
               let hour = Int(normalized[hourRange]) {
                var minute = 0
                if match.numberOfRanges >= 3,
                   let minuteRange = Range(match.range(at: 2), in: normalized),
                   let parsedMinute = Int(normalized[minuteRange]),
                   parsedMinute <= 59 {
                    minute = parsedMinute
                }
                var adjustedHour = hour
                if match.numberOfRanges >= 4,
                   let ampmRange = Range(match.range(at: match.numberOfRanges - 1), in: normalized) {
                    let ampm = normalized[ampmRange]
                    if ampm == "pm", hour < 12 { adjustedHour += 12 }
                    if ampm == "am", hour == 12 { adjustedHour = 0 }
                }
                return (adjustedHour, minute)
            }
        }
        return nil
    }

    private static func parseApplicationOpenedTrigger(normalized: String) -> DexterRoutineTrigger? {
        guard normalized.contains("when i open ") || normalized.contains("when i launch ") else { return nil }
        let knownApps: [(String, String, String)] = [
            ("vscode", "com.microsoft.VSCode", "VS Code"),
            ("vs code", "com.microsoft.VSCode", "VS Code"),
            ("xcode", "com.apple.dt.Xcode", "Xcode"),
            ("safari", "com.apple.Safari", "Safari"),
            ("chrome", "com.google.Chrome", "Chrome")
        ]
        for (needle, bundleId, displayName) in knownApps where normalized.contains(needle) {
            return DexterRoutineTrigger(
                kind: .applicationOpened,
                applicationBundleIdentifier: bundleId,
                applicationDisplayName: displayName
            )
        }
        return DexterRoutineTrigger(
            kind: .applicationOpened,
            applicationBundleIdentifier: nil,
            applicationDisplayName: "that app"
        )
    }
}
