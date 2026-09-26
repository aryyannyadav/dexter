//
//  DexterTeachingSessionStore.swift
//  leanring-buddy
//

import Combine
import Foundation

/// Session-scoped teaching progress (no screenshot bytes or screen inventory in memory).
@MainActor
final class DexterTeachingSessionStore: ObservableObject {
    @Published private(set) var activeSession: DexterTeachingSession?

    func replaceSession(_ session: DexterTeachingSession?) {
        activeSession = session
    }

    func progressSummaryForSessionMemory() -> String? {
        guard let activeSession else { return nil }
        return "Teaching lesson \(activeSession.lessonIdentifier): step \(activeSession.currentStepIndex), phase \(activeSession.phase.rawValue), mode \(activeSession.teachingMode.rawValue)."
    }
}
