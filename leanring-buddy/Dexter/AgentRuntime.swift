//
//  AgentRuntime.swift
//  leanring-buddy
//

import Foundation

/// Description of a computer/browser action requested by Dexter orchestration.
struct AgentActionRequest: Equatable {
    let actionIdentifier: String
    let parameters: [String: String]
}

enum AgentActionExecutionStatus: Equatable {
    case idle
    case queued
    case running
    case succeeded
    case failed
    case cancelled
}

/// Result reported by an agent runtime after attempting an action.
struct AgentActionResult: Equatable {
    let reportedSuccess: Bool
    let message: String
    let executionStatus: AgentActionExecutionStatus
    let runtimeTaskIdentifier: String?
    let rawOutput: String?
}

struct AgentActionCancellationResult: Equatable {
    let didCancel: Bool
    let message: String
}

enum AgentRuntimeError: Error, Equatable {
    case notConfigured
    case unavailable
    case unsupportedAction(String)
    case executionFailed(String)
}

extension AgentRuntimeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "The agent runtime is not configured."
        case .unavailable:
            return "The agent runtime is unavailable."
        case .unsupportedAction(let message):
            return message
        case .executionFailed(let message):
            return message
        }
    }
}

/// Executes tool/computer actions. Implementations must stay behind this boundary.
protocol AgentRuntime: AnyObject {
    var runtimeName: String { get }
    var currentExecutionStatus: AgentActionExecutionStatus { get }
    func isAvailable() -> Bool
    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult
    func cancelCurrentAction() async -> AgentActionCancellationResult
}

final class OpenClawAgentRuntimeAdapter: AgentRuntime {
    let runtimeName = "OpenClaw"

    private let fileManager: FileManager
    private let openClawApplicationURL: URL
    private var runningProcess: Process?
    private(set) var currentExecutionStatus: AgentActionExecutionStatus = .idle

    init(
        openClawApplicationURL: URL = URL(fileURLWithPath: "/Applications/OpenClaw.app"),
        fileManager: FileManager = .default
    ) {
        self.openClawApplicationURL = openClawApplicationURL
        self.fileManager = fileManager
    }

    func isAvailable() -> Bool {
        openClawExecutableURL() != nil
    }

    func executeAction(_ actionRequest: AgentActionRequest) async throws -> AgentActionResult {
        guard let openClawExecutableURL = openClawExecutableURL(),
              let openClawBinaryDirectoryURL = openClawBinaryDirectoryURL()
        else {
            throw AgentRuntimeError.unavailable
        }

        guard actionRequest.actionIdentifier == DexterActionType.openApplication.rawValue,
              actionRequest.parameters["applicationName"] == "Safari"
        else {
            throw AgentRuntimeError.unsupportedAction("Dexter only allows the safe Open Safari action right now.")
        }

        currentExecutionStatus = .queued
        let messageFileURL = try writeTemporaryMessageFile(for: actionRequest)
        defer {
            try? fileManager.removeItem(at: messageFileURL)
        }

        let process = Process()
        process.executableURL = openClawExecutableURL
        process.arguments = [
            "agent",
            "exec",
            "--json",
            "--timeout",
            "45",
            "--message-file",
            messageFileURL.path
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = "\(openClawBinaryDirectoryURL.path):\(existingPath)"
        process.environment = environment

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        runningProcess = process
        currentExecutionStatus = .running

        let terminationStatus = try await run(process: process)
        runningProcess = nil

        let standardOutput = String(data: standardOutputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let standardError = String(data: standardErrorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combinedOutput = [standardOutput, standardError]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        let envelope = Self.decodeAgentExecEnvelope(from: combinedOutput)
        if terminationStatus == 0, envelope?.ok != false, envelope?.status != "error" {
            currentExecutionStatus = .succeeded
            return AgentActionResult(
                reportedSuccess: true,
                message: envelope?.final?.nonEmptyTrimmedValue ?? "OpenClaw completed the approved Safari action.",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: envelope?.sessionId,
                rawOutput: combinedOutput
            )
        }

        currentExecutionStatus = .failed
        let failureMessage = envelope?.error?.message?.nonEmptyTrimmedValue
            ?? envelope?.final?.nonEmptyTrimmedValue
            ?? combinedOutput.nonEmptyTrimmedValue
            ?? "OpenClaw exited with status \(terminationStatus)."
        return AgentActionResult(
            reportedSuccess: false,
            message: "OpenClaw could not execute the approved Safari action: \(failureMessage)",
            executionStatus: .failed,
            runtimeTaskIdentifier: envelope?.sessionId,
            rawOutput: combinedOutput
        )
    }

    func cancelCurrentAction() async -> AgentActionCancellationResult {
        guard let runningProcess else {
            return AgentActionCancellationResult(
                didCancel: false,
                message: "OpenClaw has no running action to cancel."
            )
        }

        runningProcess.terminate()
        currentExecutionStatus = .cancelled
        self.runningProcess = nil
        return AgentActionCancellationResult(
            didCancel: true,
            message: "Requested cancellation for the running OpenClaw action."
        )
    }

    private func openClawBinaryDirectoryURL() -> URL? {
        let architectureDirectoryName = currentArchitectureDirectoryName()
        let preferredDirectoryURL = openClawApplicationURL
            .appendingPathComponent("Contents/Resources/node-worker/\(architectureDirectoryName)/bin")
        if fileManager.fileExists(atPath: preferredDirectoryURL.path) {
            return preferredDirectoryURL
        }

        for fallbackArchitectureDirectoryName in ["arm64", "x86_64"] where fallbackArchitectureDirectoryName != architectureDirectoryName {
            let fallbackDirectoryURL = openClawApplicationURL
                .appendingPathComponent("Contents/Resources/node-worker/\(fallbackArchitectureDirectoryName)/bin")
            if fileManager.fileExists(atPath: fallbackDirectoryURL.path) {
                return fallbackDirectoryURL
            }
        }

        return nil
    }

    private func openClawExecutableURL() -> URL? {
        guard let openClawBinaryDirectoryURL = openClawBinaryDirectoryURL() else { return nil }
        let executableURL = openClawBinaryDirectoryURL.appendingPathComponent("openclaw")
        guard fileManager.fileExists(atPath: executableURL.path) else { return nil }
        return executableURL
    }

    private func currentArchitectureDirectoryName() -> String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    private func writeTemporaryMessageFile(for actionRequest: AgentActionRequest) throws -> URL {
        let applicationName = actionRequest.parameters["applicationName"] ?? "Safari"
        let contextSummary = actionRequest.parameters["contextSummary"] ?? "No additional Dexter context was provided."
        let message = """
        Dexter has approved exactly one safe computer action.

        Action: Open \(applicationName).
        Context: \(contextSummary)

        Use OpenClaw's available computer/browser tools to open \(applicationName). Do not perform any other action. After attempting it, report whether \(applicationName) was opened.
        """

        let messageFileURL = fileManager.temporaryDirectory
            .appendingPathComponent("dexter-openclaw-action-\(UUID().uuidString).txt")
        try message.write(to: messageFileURL, atomically: true, encoding: .utf8)
        return messageFileURL
    }

    private func run(process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { completedProcess in
                continuation.resume(returning: completedProcess.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func decodeAgentExecEnvelope(from output: String) -> OpenClawAgentExecEnvelope? {
        guard let firstOpeningBraceIndex = output.firstIndex(of: "{"),
              let lastClosingBraceIndex = output.lastIndex(of: "}"),
              firstOpeningBraceIndex <= lastClosingBraceIndex
        else {
            return nil
        }

        var candidateStartIndex = firstOpeningBraceIndex
        while candidateStartIndex <= lastClosingBraceIndex {
            let jsonCandidate = String(output[candidateStartIndex...lastClosingBraceIndex])
            if let data = jsonCandidate.data(using: .utf8),
               let envelope = try? JSONDecoder().decode(OpenClawAgentExecEnvelope.self, from: data) {
                return envelope
            }

            guard let nextOpeningBraceIndex = output[output.index(after: candidateStartIndex)...lastClosingBraceIndex].firstIndex(of: "{") else {
                break
            }
            candidateStartIndex = nextOpeningBraceIndex
        }

        return nil
    }
}

private struct OpenClawAgentExecEnvelope: Decodable {
    let ok: Bool?
    let status: String?
    let final: String?
    let sessionId: String?
    let error: OpenClawAgentExecError?
}

private struct OpenClawAgentExecError: Decodable {
    let message: String?
}

private extension String {
    var nonEmptyTrimmedValue: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
