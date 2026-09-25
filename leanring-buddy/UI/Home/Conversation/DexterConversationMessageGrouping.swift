//
//  DexterConversationMessageGrouping.swift
//  leanring-buddy
//

import Foundation

struct DexterConversationMessageGroup: Identifiable, Equatable {
    let id: UUID
    let role: DexterChatMessage.Role
    let messages: [DexterChatMessage]
    let timestamp: Date?
    let showsTimestamp: Bool
}

enum DexterConversationMessageGrouper {
    private static let intraGroupTimeInterval: TimeInterval = 3 * 60
    private static let timestampGapInterval: TimeInterval = 5 * 60

    static func makeGroups(from messages: [DexterChatMessage]) -> [DexterConversationMessageGroup] {
        guard !messages.isEmpty else { return [] }

        var groups: [DexterConversationMessageGroup] = []
        var batch: [DexterChatMessage] = [messages[0]]
        var lastMessageInPreviousGroup: DexterChatMessage?

        for index in 1..<messages.count {
            let message = messages[index]
            let previousInBatch = batch.last!
            let continuesGroup = message.role == previousInBatch.role
                && message.timestamp.timeIntervalSince(previousInBatch.timestamp) <= intraGroupTimeInterval

            if continuesGroup {
                batch.append(message)
            } else {
                groups.append(makeGroup(messages: batch, previousAnchor: lastMessageInPreviousGroup))
                lastMessageInPreviousGroup = batch.last
                batch = [message]
            }
        }

        groups.append(makeGroup(messages: batch, previousAnchor: lastMessageInPreviousGroup))
        return groups
    }

    private static func makeGroup(
        messages: [DexterChatMessage],
        previousAnchor: DexterChatMessage?
    ) -> DexterConversationMessageGroup {
        let firstTimestamp = messages[0].timestamp
        let showsTimestamp: Bool
        if let previousAnchor {
            showsTimestamp = firstTimestamp.timeIntervalSince(previousAnchor.timestamp) > timestampGapInterval
        } else {
            showsTimestamp = true
        }

        return DexterConversationMessageGroup(
            id: messages[0].id,
            role: messages[0].role,
            messages: messages,
            timestamp: showsTimestamp ? firstTimestamp : nil,
            showsTimestamp: showsTimestamp
        )
    }
}

enum DexterConversationTimestampFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayAndTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d · j:mm")
        return formatter
    }()

    static func label(for date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }
        return dayAndTimeFormatter.string(from: date)
    }
}
