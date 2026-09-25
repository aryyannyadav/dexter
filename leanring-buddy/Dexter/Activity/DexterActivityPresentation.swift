//
//  DexterActivityPresentation.swift
//  leanring-buddy
//

import Foundation

enum DexterActivityDaySection: Identifiable, Equatable, Hashable {
    case today
    case yesterday
    case earlier(title: String)

    var id: String {
        switch self {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .earlier(let title): return "earlier-\(title)"
        }
    }

    var title: String {
        switch self {
        case .today: return "TODAY"
        case .yesterday: return "YESTERDAY"
        case .earlier(let title): return title.uppercased()
        }
    }
}

enum DexterActivityPresentation {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static func daySection(for date: Date, calendar: Calendar = .current) -> DexterActivityDaySection {
        if calendar.isDateInToday(date) {
            return .today
        }
        if calendar.isDateInYesterday(date) {
            return .yesterday
        }
        return .earlier(title: dayTitleFormatter.string(from: date))
    }

    static func groupedSections(from events: [DexterActivityRecord]) -> [(section: DexterActivityDaySection, events: [DexterActivityRecord])] {
        var grouped: [DexterActivityDaySection: [DexterActivityRecord]] = [:]
        var sectionOrder: [DexterActivityDaySection] = []

        for event in events {
            let section = daySection(for: event.timestamp)
            if grouped[section] == nil {
                sectionOrder.append(section)
                grouped[section] = []
            }
            grouped[section]?.append(event)
        }

        return sectionOrder.compactMap { section in
            guard let events = grouped[section] else { return nil }
            return (section, events)
        }
    }

    static func timeLabel(for date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func relativeTimestampLabel(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func statusLabel(for status: DexterActivityStatus) -> String {
        switch status {
        case .completed: return "Completed"
        case .verified: return "Verified"
        case .partiallyVerified: return "Partially verified"
        case .failed: return "Failed"
        case .needsPermission: return "Needs permission"
        case .cancelled: return "Cancelled"
        case .timedOut: return "Timed out"
        case .running: return "Running"
        }
    }

    static func systemImageName(for kind: DexterActivityKind, status: DexterActivityStatus) -> String {
        switch status {
        case .failed, .timedOut:
            return "xmark.circle.fill"
        case .needsPermission:
            return "hand.raised.circle.fill"
        case .cancelled:
            return "minus.circle.fill"
        default:
            break
        }
        switch kind {
        case .action: return "checkmark.circle.fill"
        case .routine: return "clock.arrow.circlepath"
        case .memory: return "brain.head.profile"
        case .workspace: return "folder.badge.plus"
        case .suggestion: return "lightbulb.fill"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        }
    }

    static func accessibilityLabel(for record: DexterActivityRecord) -> String {
        let when = relativeTimestampLabel(for: record.timestamp)
        let status = statusLabel(for: record.status)
        if let summary = record.summary, !summary.isEmpty {
            return "\(record.title), \(summary), \(status), \(when)"
        }
        return "\(record.title), \(status), \(when)"
    }
}
