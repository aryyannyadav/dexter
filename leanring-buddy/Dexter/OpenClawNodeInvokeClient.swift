//
//  OpenClawNodeInvokeClient.swift
//  leanring-buddy
//

import Foundation

struct OpenClawNodeInvokeResult: Equatable {
    let ok: Bool
    let errorMessage: String?
    let combinedOutput: String
}

/// Invokes paired-node commands through the local Gateway (`openclaw nodes invoke`).
final class OpenClawNodeInvokeClient {
    private let localEnvironment: OpenClawLocalEnvironment
    private var runningProcess: Process?

    init(localEnvironment: OpenClawLocalEnvironment = OpenClawLocalEnvironment()) {
        self.localEnvironment = localEnvironment
    }

    func invoke(
        nodeIdentifier: String,
        command: String,
        parametersJSON: String,
        invokeTimeoutMilliseconds: Int = 60_000
    ) async throws -> OpenClawNodeInvokeResult {
        guard let openClawExecutableURL = localEnvironment.openClawExecutableURL else {
            throw AgentRuntimeError.unavailable
        }

        let process = Process()
        process.executableURL = openClawExecutableURL
        process.arguments = [
            "nodes",
            "invoke",
            "--json",
            "--node",
            nodeIdentifier,
            "--command",
            command,
            "--params",
            parametersJSON,
            "--invoke-timeout",
            String(invokeTimeoutMilliseconds)
        ]
        process.environment = localEnvironment.augmentedProcessEnvironment()
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        runningProcess = process

        let terminationStatus = try await run(process: process)
        runningProcess = nil

        let standardOutput = String(
            data: standardOutputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let standardError = String(
            data: standardErrorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let combinedOutput = [standardOutput, standardError]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        let envelope = OpenClawNodesInvokeJSONParser.parse(from: combinedOutput)
        let ok = envelope?.ok == true && terminationStatus == 0
        let errorMessage = envelope?.error?.message

        return OpenClawNodeInvokeResult(
            ok: ok,
            errorMessage: errorMessage,
            combinedOutput: combinedOutput
        )
    }

    func cancelRunningInvoke() {
        runningProcess?.terminate()
        runningProcess = nil
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
}

enum OpenClawNodesInvokeJSONParser {
    static func parse(from output: String) -> OpenClawNodesInvokeEnvelope? {
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
               let envelope = try? JSONDecoder().decode(OpenClawNodesInvokeEnvelope.self, from: data) {
                return envelope
            }

            guard let nextOpeningBraceIndex = output[output.index(after: candidateStartIndex)...lastClosingBraceIndex]
                .firstIndex(of: "{")
            else {
                break
            }
            candidateStartIndex = nextOpeningBraceIndex
        }

        return nil
    }
}

struct OpenClawNodesInvokeEnvelope: Decodable {
    let ok: Bool?
    let error: OpenClawNodesInvokeErrorEnvelope?
}

struct OpenClawNodesInvokeErrorEnvelope: Decodable {
    let message: String?
}

enum OpenClawComputerActRequestBuilder {
    static func launchApplicationParametersJSON(
        applicationName: String,
        executionIdentifier: String
    ) -> String {
        computerActParametersJSON(
            executionIdentifier: executionIdentifier,
            actionName: "launch_app",
            fields: ["app": applicationName]
        )
    }

    static func killApplicationParametersJSON(
        applicationName: String,
        executionIdentifier: String
    ) -> String {
        computerActParametersJSON(
            executionIdentifier: executionIdentifier,
            actionName: "kill_app",
            fields: ["app": applicationName]
        )
    }

    static func closeExecutionParametersJSON(executionIdentifier: String, reason: String) -> String {
        computerActParametersJSON(
            executionIdentifier: executionIdentifier,
            actionName: "__close_execution",
            fields: ["reason": reason]
        )
    }

    static func computerActParametersJSON(
        executionIdentifier: String,
        actionName: String,
        fields: [String: String]
    ) -> String {
        var payload: [String: Any] = [
            "executionId": executionIdentifier,
            "action": actionName
        ]
        for (fieldKey, fieldValue) in fields {
            payload[fieldKey] = fieldValue
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}

/// Runs one bounded OpenClaw computer.act execution with a fresh executionId and closes it when finished.
enum OpenClawComputerActExecutor {
    static func performComputerAct(
        nodeIdentifier: String,
        nodeInvokeClient: OpenClawNodeInvokeClient,
        parametersJSON: String,
        executionIdentifier: String
    ) async throws -> OpenClawNodeInvokeResult {
        DexterOpenClawLog.log("command=computer.act")
        let invokeResult = try await nodeInvokeClient.invoke(
            nodeIdentifier: nodeIdentifier,
            command: "computer.act",
            parametersJSON: parametersJSON
        )

        let closeParametersJSON = OpenClawComputerActRequestBuilder.closeExecutionParametersJSON(
            executionIdentifier: executionIdentifier,
            reason: "dexter-complete"
        )
        _ = try? await nodeInvokeClient.invoke(
            nodeIdentifier: nodeIdentifier,
            command: "computer.act",
            parametersJSON: closeParametersJSON,
            invokeTimeoutMilliseconds: 10_000
        )

        return invokeResult
    }
}
