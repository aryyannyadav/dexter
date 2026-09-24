//
//  OpenClawCLIProcessRunner.swift
//  leanring-buddy
//

import Foundation

enum OpenClawCLIProcessRunner {
    static func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        workingDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory())
    ) async throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = workingDirectoryURL

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { _ in
                continuation.resume()
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        let standardOutput = String(
            data: standardOutputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let standardError = String(
            data: standardErrorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        return [standardOutput, standardError].joined(separator: "\n")
    }
}
