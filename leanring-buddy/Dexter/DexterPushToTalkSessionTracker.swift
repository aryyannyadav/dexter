//
//  DexterPushToTalkSessionTracker.swift
//  leanring-buddy
//

import Foundation

/// Ensures a single PTT key release only finalizes STT once per press cycle.
final class DexterPushToTalkSessionTracker {
    private var activeSessionIdentifier: UUID?
    private var didHandleReleaseForActiveSession = false

    func beginSession() -> UUID {
        let sessionIdentifier = UUID()
        activeSessionIdentifier = sessionIdentifier
        didHandleReleaseForActiveSession = false
        return sessionIdentifier
    }

    func handleRelease(for sessionIdentifier: UUID) -> Bool {
        guard activeSessionIdentifier == sessionIdentifier else {
            return false
        }
        guard !didHandleReleaseForActiveSession else {
            return false
        }
        didHandleReleaseForActiveSession = true
        return true
    }

    func clearSession(for sessionIdentifier: UUID) {
        if activeSessionIdentifier == sessionIdentifier {
            activeSessionIdentifier = nil
            didHandleReleaseForActiveSession = false
        }
    }
}
