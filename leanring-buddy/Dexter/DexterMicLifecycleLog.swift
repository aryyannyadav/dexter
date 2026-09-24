//
//  DexterMicLifecycleLog.swift
//  leanring-buddy
//

import Foundation

enum DexterMicLifecycleLog {
    static func startRequested(id: UUID) {
        print("[MIC-LIFECYCLE] START requested id=\(short(id))")
    }

    static func startAsyncBegin(id: UUID) {
        print("[MIC-LIFECYCLE] START async begin id=\(short(id))")
    }

    static func providerOpening(id: UUID) {
        print("[MIC-LIFECYCLE] PROVIDER opening id=\(short(id))")
    }

    static func providerReady(id: UUID) {
        print("[MIC-LIFECYCLE] PROVIDER ready id=\(short(id))")
    }

    static func audioStarted(id: UUID) {
        print("[MIC-LIFECYCLE] AUDIO STARTED id=\(short(id))")
    }

    static func stopRequested(id: UUID?) {
        let identifier = id.map(short) ?? "none"
        print("[MIC-LIFECYCLE] STOP requested id=\(identifier)")
    }

    static func stopIgnored(id: UUID?, reason: String) {
        let identifier = id.map(short) ?? "none"
        print("[MIC-LIFECYCLE] STOP ignored id=\(identifier) reason=\(reason)")
    }

    private static func short(_ id: UUID) -> String {
        id.uuidString.prefix(8).description
    }
}
