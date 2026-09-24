//
//  DexterLocalTerminalToolExecutor.swift
//  leanring-buddy
//

import Foundation

final class DexterLocalTerminalToolExecutor {
    static let shared = DexterLocalTerminalToolExecutor()

    private var runningProcess: Process?
    private let processLock = NSLock()

    func cancelRunningProcess() {
        processLock.lock()
        let process = runningProcess
        processLock.unlock()
        process?.terminate()
    }

    func execute(toolInvocation: DexterToolInvocation) async -> DexterToolGatewayOutcome {
        let terminalAction = toolInvocation.parameters["terminalAction"] ?? "inspect"
        switch DexterTerminalCommandPolicy.resolve(terminalAction: terminalAction, parameters: toolInvocation.parameters) {
        case .rejected(let reason):
            return .dispatchFailed(message: reason, rawOutput: nil)
        case .approved(let executablePath, let arguments, let workingDirectoryURL, _):
            return await runProcess(
                terminalAction: terminalAction,
                executablePath: executablePath,
                arguments: arguments,
                workingDirectoryURL: workingDirectoryURL,
                expectedOutputContains: toolInvocation.parameters["expectedOutputContains"]
            )
        }
    }

    private func runProcess(
        terminalAction: String,
        executablePath: String,
        arguments: [String],
        workingDirectoryURL: URL?,
        expectedOutputContains: String?
    ) async -> DexterToolGatewayOutcome {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            if let workingDirectoryURL {
                process.currentDirectoryURL = workingDirectoryURL
            }
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            processLock.lock()
            runningProcess = process
            processLock.unlock()

            process.terminationHandler = { [weak self] finishedProcess in
                self?.processLock.lock()
                self?.runningProcess = nil
                self?.processLock.unlock()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let combined = String(decoding: stdoutData, as: UTF8.self)
                    + String(decoding: stderrData, as: UTF8.self)
                let sanitized = DexterTerminalOutputSanitizer.sanitizeAndTruncate(combined)

                let payload = DexterTerminalOperationResultPayload(
                    terminalAction: terminalAction,
                    exitCode: finishedProcess.terminationStatus,
                    output: sanitized,
                    expectedOutputContains: expectedOutputContains
                )

                if finishedProcess.terminationStatus == 0 {
                    continuation.resume(
                        returning: .dispatchSucceeded(
                            runtimeTaskIdentifier: UUID().uuidString,
                            rawOutput: payload.encodedJSON()
                        )
                    )
                } else {
                    continuation.resume(
                        returning: .dispatchFailed(
                            message: "Command exited with status \(finishedProcess.terminationStatus).",
                            rawOutput: payload.encodedJSON()
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                processLock.lock()
                runningProcess = nil
                processLock.unlock()
                continuation.resume(
                    returning: .dispatchFailed(message: "Could not start process: \(error.localizedDescription)", rawOutput: nil)
                )
                return
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(DexterTerminalCommandPolicy.executionTimeoutSeconds * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }
}

struct DexterTerminalOperationResultPayload: Equatable {
    let terminalAction: String
    let exitCode: Int32
    let output: String
    let expectedOutputContains: String?

    func encodedJSON() -> String {
        var object: [String: Any] = [
            "terminalAction": terminalAction,
            "exitCode": exitCode,
            "output": output
        ]
        if let expectedOutputContains {
            object["expectedOutputContains"] = expectedOutputContains
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func decode(from rawOutput: String?) -> DexterTerminalOperationResultPayload? {
        guard let rawOutput,
              let data = rawOutput.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return DexterTerminalOperationResultPayload(
            terminalAction: object["terminalAction"] as? String ?? "",
            exitCode: Int32(object["exitCode"] as? Int ?? -1),
            output: object["output"] as? String ?? "",
            expectedOutputContains: object["expectedOutputContains"] as? String
        )
    }
}
