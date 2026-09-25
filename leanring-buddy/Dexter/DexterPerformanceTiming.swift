//
//  DexterPerformanceTiming.swift
//  leanring-buddy
//

import Foundation

enum DexterPerformanceTiming {
    private static var hotkeyReleasedAt: Date?
    private static var inputReceivedAt: Date?
    private static var routingCompletedAt: Date?
    private static var modelGenerationStartedAt: Date?
    private static var firstTokenReceivedAt: Date?

    static func markInputReceived() {
        inputReceivedAt = Date()
        routingCompletedAt = nil
        modelGenerationStartedAt = nil
        firstTokenReceivedAt = nil
        DexterObservabilityLog.perf("input_received")
    }

    static func markRoutingCompleted(route: DexterRequestRoute) {
        routingCompletedAt = Date()
        if let inputReceivedAt {
            let milliseconds = Int(Date().timeIntervalSince(inputReceivedAt) * 1000)
            DexterObservabilityLog.perf("routing_ms=\(milliseconds) route=\(route.rawValue)")
        } else {
            DexterObservabilityLog.perf("routing_complete route=\(route.rawValue)")
        }
    }

    static func markModelGenerationStarted() {
        modelGenerationStartedAt = Date()
        if let routingCompletedAt {
            let milliseconds = Int(Date().timeIntervalSince(routingCompletedAt) * 1000)
            DexterObservabilityLog.perf("model_start_after_routing_ms=\(milliseconds)")
        } else if let inputReceivedAt {
            let milliseconds = Int(Date().timeIntervalSince(inputReceivedAt) * 1000)
            DexterObservabilityLog.perf("model_start_after_input_ms=\(milliseconds)")
        } else {
            DexterObservabilityLog.perf("model_generation_started")
        }
    }

    static func markFirstTokenReceived() {
        guard firstTokenReceivedAt == nil else { return }
        firstTokenReceivedAt = Date()
        if let modelGenerationStartedAt {
            let milliseconds = Int(Date().timeIntervalSince(modelGenerationStartedAt) * 1000)
            DexterObservabilityLog.perf("first_token_ms=\(milliseconds)")
        } else {
            DexterObservabilityLog.perf("first_token_received")
        }
    }

    static func markResponseCompleted() {
        if let inputReceivedAt {
            let milliseconds = Int(Date().timeIntervalSince(inputReceivedAt) * 1000)
            DexterObservabilityLog.perf("response_complete_ms=\(milliseconds)")
        }
        inputReceivedAt = nil
        routingCompletedAt = nil
        modelGenerationStartedAt = nil
        firstTokenReceivedAt = nil
    }

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
        inputReceivedAt = nil
        routingCompletedAt = nil
        modelGenerationStartedAt = nil
        firstTokenReceivedAt = nil
    }
    #endif
}
