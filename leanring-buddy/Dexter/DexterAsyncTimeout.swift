//
//  DexterAsyncTimeout.swift
//  leanring-buddy
//

import Foundation

struct DexterModelRequestTimeoutError: LocalizedError {
    let timeoutSeconds: TimeInterval

    var errorDescription: String? {
        "Dexter timed out after \(Int(timeoutSeconds)) seconds. Try again or check that Ollama is responding."
    }
}

struct DexterContextAssemblyTimeoutError: LocalizedError {
    let timeoutSeconds: TimeInterval

    var errorDescription: String? {
        "Dexter timed out while gathering context after \(Int(timeoutSeconds)) seconds."
    }
}

struct DexterSpeechToTextTimeoutError: LocalizedError {
    let timeoutSeconds: TimeInterval

    var errorDescription: String? {
        "Dexter timed out waiting for speech transcription after \(Int(timeoutSeconds)) seconds."
    }
}

enum DexterAsyncTimeout {
    static func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { taskGroup in
            taskGroup.addTask {
                try await operation()
            }
            taskGroup.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw DexterModelRequestTimeoutError(timeoutSeconds: seconds)
            }

            guard let result = try await taskGroup.next() else {
                throw DexterModelRequestTimeoutError(timeoutSeconds: seconds)
            }
            taskGroup.cancelAll()
            return result
        }
    }
}
