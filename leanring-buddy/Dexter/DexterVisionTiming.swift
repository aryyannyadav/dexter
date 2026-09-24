//
//  DexterVisionTiming.swift
//  leanring-buddy
//

import Foundation

/// Per-turn vision latency markers (screen capture → JPEG → Ollama). Text-only turns do not activate this.
enum DexterVisionTiming {
    private static var isActive = false
    private static var turnStartedAt: Date?
    private static var captureStartedAt: Date?
    private static var captureCompletedAt: Date?
    private static var jpegStartedAt: Date?
    private static var jpegCompletedAt: Date?
    private static var ollamaRequestSentAt: Date?
    private static var ollamaFirstByteAt: Date?
    private static var ollamaResponseCompletedAt: Date?
    private static var parseCompletedAt: Date?
    private static var turnCompletedAt: Date?

    static func beginVisionTurn() {
        reset()
        isActive = true
        turnStartedAt = Date()
        print("[VISION-TIMING] vision turn started")
    }

    static func reset() {
        isActive = false
        turnStartedAt = nil
        captureStartedAt = nil
        captureCompletedAt = nil
        jpegStartedAt = nil
        jpegCompletedAt = nil
        ollamaRequestSentAt = nil
        ollamaFirstByteAt = nil
        ollamaResponseCompletedAt = nil
        parseCompletedAt = nil
        turnCompletedAt = nil
    }

    static func markCaptureStarted() {
        guard isActive else { return }
        captureStartedAt = Date()
    }

    static func markCaptureCompleted() {
        guard isActive else { return }
        captureCompletedAt = Date()
    }

    static func markJPEGEncodingStarted() {
        guard isActive else { return }
        jpegStartedAt = Date()
    }

    static func markJPEGEncodingCompleted(
        originalPixelWidth: Int,
        originalPixelHeight: Int,
        jpegPixelWidth: Int,
        jpegPixelHeight: Int,
        jpegByteCount: Int,
        base64CharacterCount: Int
    ) {
        guard isActive else { return }
        jpegCompletedAt = Date()
        print(
            "[VISION-TIMING] image original=\(originalPixelWidth)x\(originalPixelHeight) "
                + "jpeg=\(jpegPixelWidth)x\(jpegPixelHeight) jpegBytes=\(jpegByteCount) base64Length=\(base64CharacterCount)"
        )
    }

    static func markOllamaHTTPRequestSent() {
        guard isActive else { return }
        ollamaRequestSentAt = Date()
        print("[VISION-TIMING] ollama HTTP request sent")
    }

    static func markOllamaHTTPResponseReceived(httpStatus: Int) {
        guard isActive else { return }
        let now = Date()
        if ollamaFirstByteAt == nil {
            ollamaFirstByteAt = now
        }
        ollamaResponseCompletedAt = now
        let elapsedMilliseconds = milliseconds(from: ollamaRequestSentAt, to: now) ?? -1
        print("[VISION-TIMING] ollama HTTP response received status=\(httpStatus) elapsed=\(elapsedMilliseconds)ms")
    }

    static func markResponseParseCompleted(succeeded: Bool, responseTextLength: Int) {
        guard isActive else { return }
        parseCompletedAt = Date()
        print(
            "[VISION-TIMING] parse completed succeeded=\(succeeded) responseTextLength=\(responseTextLength)"
        )
    }

    static func markTurnCompleted() {
        guard isActive else { return }
        turnCompletedAt = Date()
        logSummary()
        reset()
    }

    static func logTimeout(afterSeconds: TimeInterval) {
        guard isActive else { return }
        print("[VISION-TIMING] TIMEOUT after \(Int(afterSeconds))")
        logSummary()
        reset()
    }

    private static func logSummary() {
        let captureMilliseconds = milliseconds(from: captureStartedAt, to: captureCompletedAt)
        let jpegMilliseconds = milliseconds(from: jpegStartedAt, to: jpegCompletedAt)
        let ollamaRequestMilliseconds = milliseconds(from: ollamaRequestSentAt, to: ollamaFirstByteAt ?? ollamaResponseCompletedAt)
        let ollamaResponseMilliseconds = milliseconds(from: ollamaFirstByteAt ?? ollamaRequestSentAt, to: ollamaResponseCompletedAt)
        let parseMilliseconds = milliseconds(from: ollamaResponseCompletedAt, to: parseCompletedAt)
        let totalMilliseconds = milliseconds(from: turnStartedAt, to: turnCompletedAt ?? Date())

        print("[VISION-TIMING]")
        print("capture=\(formatMilliseconds(captureMilliseconds))")
        print("jpeg=\(formatMilliseconds(jpegMilliseconds))")
        print("ollama_request=\(formatMilliseconds(ollamaRequestMilliseconds))")
        print("ollama_response=\(formatMilliseconds(ollamaResponseMilliseconds))")
        if let parseMilliseconds {
            print("parse=\(formatMilliseconds(parseMilliseconds))")
        }
        print("total=\(formatMilliseconds(totalMilliseconds))")
    }

    private static func milliseconds(from start: Date?, to end: Date?) -> Int? {
        guard let start, let end else { return nil }
        return Int(end.timeIntervalSince(start) * 1000)
    }

    private static func formatMilliseconds(_ value: Int?) -> String {
        guard let value else { return "n/a" }
        return "\(value)ms"
    }
}
