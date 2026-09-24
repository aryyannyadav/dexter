//
//  DexterFileTerminalIntelligenceTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterFileTerminalIntelligenceTests {
    @Test func pathPolicyRejectsOutsideApprovedRoots() {
        let decision = DexterApprovedFilePathPolicy.evaluate(path: "/etc/hosts")
        guard case .rejected = decision else {
            Issue.record("Expected rejection for /etc/hosts")
            return
        }
    }

    @Test func terminalPolicyRejectsRawCommandField() {
        let resolution = DexterTerminalCommandPolicy.resolve(
            terminalAction: "inspect",
            parameters: ["command": "rm -rf /"]
        )
        guard case .rejected(let reason) = resolution else {
            Issue.record("Expected rejection for raw command.")
            return
        }
        #expect(reason.contains("commandTemplate"))
    }

    @Test func terminalPolicyApprovesInspectPwdTemplate() {
        let resolution = DexterTerminalCommandPolicy.resolve(
            terminalAction: "inspect",
            parameters: ["commandTemplate": "inspect_pwd"]
        )
        guard case .approved(let executablePath, _, _, let readOnly) = resolution else {
            Issue.record("Expected approved inspect_pwd template.")
            return
        }
        #expect(executablePath == "/bin/pwd")
        #expect(readOnly)
    }

    @Test func fileCreateVerificationRequiresExistingFile() {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/dexter-file-verify-\(UUID().uuidString).txt")
        let action = DexterActionFactory.fileOperation(
            fileAction: "create",
            path: fileURL.path,
            content: "hello",
            riskLevel: .moderateRisk,
            humanReadableDescription: "Create test file."
        )

        let missingReport = DexterFileVerificationEngine.verify(
            action: action,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "t1",
                rawOutput: nil
            )
        )
        #expect(missingReport.status == .failed)

        try? Data("hello".utf8).write(to: fileURL)
        let successReport = DexterFileVerificationEngine.verify(
            action: action,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "t1",
                rawOutput: DexterFileOperationResultPayload(
                    fileAction: "create",
                    path: fileURL.path,
                    destinationPath: nil,
                    exists: true,
                    contentPreview: "hello",
                    matchedPaths: nil
                ).encodedJSON()
            )
        )
        #expect(successReport.status == .verified)
        try? FileManager.default.removeItem(at: fileURL)
    }

    @Test func terminalVerificationFailsWithoutOutputPayload() {
        let action = DexterActionFactory.terminalOperation(
            terminalAction: "inspect",
            commandTemplate: "inspect_pwd",
            riskLevel: .readOnly,
            humanReadableDescription: "Inspect pwd."
        )
        let report = DexterTerminalVerificationEngine.verify(
            action: action,
            executionResult: AgentActionResult(
                reportedSuccess: true,
                message: "ok",
                executionStatus: .succeeded,
                runtimeTaskIdentifier: "t1",
                rawOutput: nil
            )
        )
        #expect(report.status == .failed)
        #expect(report.summary.contains("won't claim"))
    }

    @Test func registeredToolRouterMapsFileRead() {
        let homeDocuments = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/notes.txt")
        let invocation = DexterRegisteredToolRouter.toolInvocation(
            for: DexterRegisteredToolProposal(
                toolName: DexterRegisteredToolName.fileRead.rawValue,
                parameters: ["path": homeDocuments.path]
            )
        )
        #expect(invocation?.toolKind == .fileOperation)
        #expect(invocation?.parameters["fileAction"] == "read")
    }

    @Test func outputSanitizerRedactsBearerTokens() {
        let sanitized = DexterTerminalOutputSanitizer.sanitizeAndTruncate("Authorization: Bearer secret-token-value")
        #expect(sanitized.contains("[REDACTED]"))
        #expect(!sanitized.contains("secret-token-value"))
    }
}
