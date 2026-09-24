//
//  DexterTaskTrace.swift
//  leanring-buddy
//

import Foundation

enum DexterOperationalOutcomeCategory: String, Equatable, CaseIterable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case timeout = "TIMEOUT"
    case cancelled = "CANCELLED"
    case permissionDenied = "PERMISSION_DENIED"
    case verificationFailed = "VERIFICATION_FAILED"
}

enum DexterTaskTracePhase: String, Equatable, CaseIterable {
    case invocation = "INVOCATION"
    case context = "CONTEXT"
    case intent = "INTENT"
    case plan = "PLAN"
    case permission = "PERMISSION"
    case toolCalls = "TOOL_CALLS"
    case executionResults = "EXECUTION_RESULTS"
    case observation = "OBSERVATION"
    case verification = "VERIFICATION"
    case outcome = "OUTCOME"
}

enum DexterLatencyBucket: String, Equatable, CaseIterable {
    case context = "context"
    case model = "model"
    case tool = "tool"
    case openClaw = "openclaw"
    case verification = "verification"
    case total = "total"
    case hotkeyToContext = "hotkey_to_context"
    case screenCapture = "screen_capture"
    case pointerDetection = "pointer"
    case ocr = "ocr"
    case vision = "vision"
    case intent = "intent"
    case planning = "planning"
    case tts = "tts"
}

struct DexterTaskLatencyMetrics: Equatable {
    var contextMilliseconds: Int?
    var modelMilliseconds: Int?
    var toolMilliseconds: Int?
    var openClawMilliseconds: Int?
    var verificationMilliseconds: Int?
    var totalMilliseconds: Int?
    var hotkeyToContextMilliseconds: Int?
    var screenCaptureMilliseconds: Int?
    var pointerDetectionMilliseconds: Int?
    var ocrMilliseconds: Int?
    var visionMilliseconds: Int?
    var intentMilliseconds: Int?
    var planningMilliseconds: Int?
    var ttsMilliseconds: Int?
}

struct DexterTaskTraceSnapshot: Equatable, Identifiable {
    let taskIdentifier: UUID
    var id: UUID { taskIdentifier }
    let startedAt: Date
    let completedAt: Date?
    let outcomeCategory: DexterOperationalOutcomeCategory?
    let latencyMetrics: DexterTaskLatencyMetrics
    let completedPhases: [DexterTaskTracePhase]
}

final class DexterTaskTraceRecorder {
    static let shared = DexterTaskTraceRecorder()

    private let lock = NSLock()
    private(set) var currentTaskIdentifier: UUID?
    private var taskStartedAt: Date?
    private var latencyMetrics = DexterTaskLatencyMetrics()
    private var completedPhases: [DexterTaskTracePhase] = []
    private var lastOutcome: DexterOperationalOutcomeCategory?

    private init() {}

    func beginTask() -> UUID {
        lock.lock()
        let taskIdentifier = UUID()
        currentTaskIdentifier = taskIdentifier
        taskStartedAt = Date()
        latencyMetrics = DexterTaskLatencyMetrics()
        completedPhases = []
        lastOutcome = nil
        appendPhase(.invocation)
        lock.unlock()
        DexterObservabilityLog.task("task_id=\(shortIdentifier(taskIdentifier)) phase=invocation started")
        return taskIdentifier
    }

    func endTask(outcome: DexterOperationalOutcomeCategory) {
        lock.lock()
        guard let taskIdentifier = currentTaskIdentifier, let taskStartedAt else {
            lock.unlock()
            return
        }
        appendPhase(.outcome)
        lastOutcome = outcome
        latencyMetrics.totalMilliseconds = milliseconds(since: taskStartedAt)

        DexterObservabilityLog.task(
            """
            task_id=\(shortIdentifier(taskIdentifier)) outcome=\(outcome.rawValue) \
            total_ms=\(latencyMetrics.totalMilliseconds ?? 0) \
            context_ms=\(latencyMetrics.contextMilliseconds ?? 0) \
            model_ms=\(latencyMetrics.modelMilliseconds ?? 0) \
            tool_ms=\(latencyMetrics.toolMilliseconds ?? 0) \
            openclaw_ms=\(latencyMetrics.openClawMilliseconds ?? 0) \
            verify_ms=\(latencyMetrics.verificationMilliseconds ?? 0) \
            hotkey_to_context_ms=\(latencyMetrics.hotkeyToContextMilliseconds ?? 0) \
            screen_capture_ms=\(latencyMetrics.screenCaptureMilliseconds ?? 0) \
            pointer_ms=\(latencyMetrics.pointerDetectionMilliseconds ?? 0) \
            ocr_ms=\(latencyMetrics.ocrMilliseconds ?? 0) \
            vision_ms=\(latencyMetrics.visionMilliseconds ?? 0) \
            intent_ms=\(latencyMetrics.intentMilliseconds ?? 0) \
            plan_ms=\(latencyMetrics.planningMilliseconds ?? 0) \
            tts_ms=\(latencyMetrics.ttsMilliseconds ?? 0)
            """
        )

        currentTaskIdentifier = nil
        self.taskStartedAt = nil
        lock.unlock()
    }

    func markPhase(_ phase: DexterTaskTracePhase) {
        lock.lock()
        appendPhase(phase)
        lock.unlock()
    }

    private func appendPhase(_ phase: DexterTaskTracePhase) {
        if completedPhases.last != phase {
            completedPhases.append(phase)
        }
    }

    func recordLatency(bucket: DexterLatencyBucket, milliseconds: Int) {
        lock.lock()
        defer { lock.unlock() }

        switch bucket {
        case .context:
            latencyMetrics.contextMilliseconds = milliseconds
        case .model:
            latencyMetrics.modelMilliseconds = milliseconds
        case .tool:
            latencyMetrics.toolMilliseconds = milliseconds
        case .openClaw:
            latencyMetrics.openClawMilliseconds = milliseconds
        case .verification:
            latencyMetrics.verificationMilliseconds = milliseconds
        case .total:
            latencyMetrics.totalMilliseconds = milliseconds
        case .hotkeyToContext:
            latencyMetrics.hotkeyToContextMilliseconds = milliseconds
        case .screenCapture:
            latencyMetrics.screenCaptureMilliseconds = milliseconds
        case .pointerDetection:
            latencyMetrics.pointerDetectionMilliseconds = milliseconds
        case .ocr:
            latencyMetrics.ocrMilliseconds = milliseconds
        case .vision:
            latencyMetrics.visionMilliseconds = milliseconds
        case .intent:
            latencyMetrics.intentMilliseconds = milliseconds
        case .planning:
            latencyMetrics.planningMilliseconds = milliseconds
        case .tts:
            latencyMetrics.ttsMilliseconds = milliseconds
        }
    }

    func measure<T>(bucket: DexterLatencyBucket, operation: () async throws -> T) async rethrows -> T {
        let startedAt = Date()
        let result = try await operation()
        recordLatency(bucket: bucket, milliseconds: milliseconds(since: startedAt))
        return result
    }

    func snapshot() -> DexterTaskTraceSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        guard let taskIdentifier = currentTaskIdentifier, let taskStartedAt else { return nil }
        return DexterTaskTraceSnapshot(
            taskIdentifier: taskIdentifier,
            startedAt: taskStartedAt,
            completedAt: lastOutcome == nil ? nil : Date(),
            outcomeCategory: lastOutcome,
            latencyMetrics: latencyMetrics,
            completedPhases: completedPhases
        )
    }

    #if DEBUG
    func resetForTesting() {
        lock.lock()
        currentTaskIdentifier = nil
        taskStartedAt = nil
        latencyMetrics = DexterTaskLatencyMetrics()
        completedPhases = []
        lastOutcome = nil
        lock.unlock()
    }
    #endif

    static func mapTurnOutcome(_ turnOutcome: DexterTurnOutcome) -> DexterOperationalOutcomeCategory {
        switch turnOutcome {
        case .success:
            return .success
        case .error:
            return .failure
        case .cancelled:
            return .cancelled
        case .timeout:
            return .timeout
        }
    }

    private func milliseconds(since date: Date) -> Int {
        Int(Date().timeIntervalSince(date) * 1_000)
    }

    private func shortIdentifier(_ identifier: UUID) -> String {
        String(identifier.uuidString.prefix(8))
    }
}
