//
//  DexterPerformanceTiming.swift
//  leanring-buddy
//

import Foundation

enum DexterPerformanceTiming {
    private static var hotkeyReleasedAt: Date?

    static func markHotkeyReleased() {
        hotkeyReleasedAt = Date()
        DexterObservabilityLog.perf("hotkey_released")
    }

    static func markContextAssemblyCompleted() {
        guard let hotkeyReleasedAt else { return }
        let milliseconds = Int(Date().timeIntervalSince(hotkeyReleasedAt) * 1000)
        DexterTaskTraceRecorder.shared.recordLatency(bucket: .hotkeyToContext, milliseconds: milliseconds)
        DexterObservabilityLog.perf("hotkey_to_context_ms=\(milliseconds)")
        self.hotkeyReleasedAt = nil
    }

    static func measureSync<T>(
        bucket: DexterLatencyBucket,
        detail: String? = nil,
        operation: () throws -> T
    ) rethrows -> T {
        let startedAt = Date()
        let result = try operation()
        let milliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
        DexterTaskTraceRecorder.shared.recordLatency(bucket: bucket, milliseconds: milliseconds)
        if let detail {
            DexterObservabilityLog.perf("\(bucket.rawValue)_ms=\(milliseconds) \(detail)")
        } else {
            DexterObservabilityLog.perf("\(bucket.rawValue)_ms=\(milliseconds)")
        }
        return result
    }

    @discardableResult
    static func measure<T>(
        bucket: DexterLatencyBucket,
        detail: String? = nil,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startedAt = Date()
        let result = try await operation()
        let milliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
        DexterTaskTraceRecorder.shared.recordLatency(bucket: bucket, milliseconds: milliseconds)
        if let detail {
            DexterObservabilityLog.perf("\(bucket.rawValue)_ms=\(milliseconds) \(detail)")
        } else {
            DexterObservabilityLog.perf("\(bucket.rawValue)_ms=\(milliseconds)")
        }
        return result
    }

    #if DEBUG
    static func resetHotkeyMarkerForTesting() {
        hotkeyReleasedAt = nil
    }
    #endif
}
