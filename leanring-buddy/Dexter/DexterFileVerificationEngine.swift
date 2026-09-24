//
//  DexterFileVerificationEngine.swift
//  leanring-buddy
//

import Foundation

enum DexterFileVerificationEngine {
    static func verify(
        action: DexterAction,
        executionResult: AgentActionResult
    ) -> DexterActionVerificationReport {
        let fileAction = action.parameters["fileAction"] ?? ""
        let path = action.parameters["path"] ?? ""
        let destinationPath = action.parameters["destinationPath"]
            ?? action.parameters["destinationPath"]
        let expectedContent = action.parameters["content"]
            ?? action.parameters["verificationContent"]

        let runtimePayload = DexterFileOperationResultPayload.decode(from: executionResult.rawOutput)

        if !executionResult.reportedSuccess {
            return failed(
                summary: "File action did not complete.",
                fileAction: fileAction,
                path: path,
                reason: executionResult.message
            )
        }

        switch fileAction {
        case "create":
            return verifyExists(path: path, shouldExist: true, runtimePayload: runtimePayload, verb: "created")
        case "delete":
            return verifyExists(path: path, shouldExist: false, runtimePayload: runtimePayload, verb: "deleted")
        case "write":
            return verifyWrite(path: path, expectedContent: expectedContent, runtimePayload: runtimePayload)
        case "move":
            return verifyMove(sourcePath: path, destinationPath: destinationPath ?? runtimePayload?.destinationPath, runtimePayload: runtimePayload)
        case "rename":
            return verifyMove(
                sourcePath: path,
                destinationPath: runtimePayload?.destinationPath ?? action.parameters["newName"],
                runtimePayload: runtimePayload
            )
        case "read", "search":
            if runtimePayload != nil || executionResult.rawOutput != nil {
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: "File \(fileAction) returned structured results.",
                    expectedStateDescription: "File \(fileAction) should complete with structured output.",
                    observedStateDescription: "Runtime returned file operation payload.",
                    confidence: 0.85,
                    evidence: ["file_payload_present=true"]
                )
            }
            return failed(summary: "File \(fileAction) missing verification payload.", fileAction: fileAction, path: path, reason: "No structured output.")
        default:
            return failed(summary: "Unknown file action for verification.", fileAction: fileAction, path: path, reason: fileAction)
        }
    }

    private static func verifyExists(
        path: String,
        shouldExist: Bool,
        runtimePayload: DexterFileOperationResultPayload?,
        verb: String
    ) -> DexterActionVerificationReport {
        let filesystemExists: Bool? = {
            switch DexterApprovedFilePathPolicy.evaluate(path: path) {
            case .approved(let url):
                return FileManager.default.fileExists(atPath: url.path)
            case .rejected:
                return nil
            }
        }()

        let observedExists = filesystemExists ?? runtimePayload?.exists
        let expectedDescription = shouldExist
            ? "File should exist at \(path) after \(verb)."
            : "File should be absent at \(path) after \(verb)."

        if let observedExists {
            if observedExists == shouldExist {
                return DexterActionVerificationReport(
                    status: .verified,
                    summary: shouldExist ? "File exists at the target path." : "File is absent at the target path.",
                    expectedStateDescription: expectedDescription,
                    observedStateDescription: "exists=\(observedExists)",
                    confidence: 0.9,
                    evidence: ["filesystem_exists=\(observedExists)"]
                )
            }
            return failed(
                summary: "File state does not match expectation after \(verb).",
                fileAction: verb,
                path: path,
                reason: "exists=\(observedExists)"
            )
        }

        return failed(
            summary: "Dexter could not confirm file state after \(verb).",
            fileAction: verb,
            path: path,
            reason: "filesystem_probe_unavailable"
        )
    }

    private static func verifyWrite(
        path: String,
        expectedContent: String?,
        runtimePayload: DexterFileOperationResultPayload?
    ) -> DexterActionVerificationReport {
        if let expectedContent {
            switch DexterApprovedFilePathPolicy.evaluate(path: path) {
            case .approved(let url):
                if let data = try? Data(contentsOf: url),
                   String(decoding: data, as: UTF8.self) == expectedContent {
                    return DexterActionVerificationReport(
                        status: .verified,
                        summary: "File content matches the expected write.",
                        expectedStateDescription: "Written file should match approved content.",
                        observedStateDescription: "On-disk content matches expected length \(expectedContent.count).",
                        confidence: 0.92,
                        evidence: ["content_match=true"]
                    )
                }
            case .rejected:
                break
            }
        }

        if runtimePayload?.contentPreview != nil || runtimePayload?.exists == true {
            return DexterActionVerificationReport(
                status: .partiallyVerified,
                summary: "File write was dispatched; full content match was not confirmed.",
                expectedStateDescription: "Written file should reflect approved content.",
                observedStateDescription: "Runtime reported write completion.",
                confidence: 0.6,
                evidence: ["runtime_write_payload=true"]
            )
        }

        return failed(summary: "Write verification failed.", fileAction: "write", path: path, reason: "content_mismatch")
    }

    private static func verifyMove(
        sourcePath: String,
        destinationPath: String?,
        runtimePayload: DexterFileOperationResultPayload?
    ) -> DexterActionVerificationReport {
        guard let destinationPath, !destinationPath.isEmpty else {
            return failed(summary: "Move verification missing destination path.", fileAction: "move", path: sourcePath, reason: "no_destination")
        }

        let sourceExists = pathExists(sourcePath)
        let destinationExists = pathExists(destinationPath)

        if sourceExists == false && destinationExists == true {
            return DexterActionVerificationReport(
                status: .verified,
                summary: "Move verified: source absent and destination present.",
                expectedStateDescription: "Source should be absent and destination should exist.",
                observedStateDescription: "sourceExists=false destinationExists=true",
                confidence: 0.9,
                evidence: ["move_verified=true"]
            )
        }

        if runtimePayload?.destinationPath != nil {
            return DexterActionVerificationReport(
                status: .partiallyVerified,
                summary: "Move dispatched; filesystem state was inconclusive.",
                expectedStateDescription: "Source absent, destination present.",
                observedStateDescription: "sourceExists=\(String(describing: sourceExists)) destinationExists=\(String(describing: destinationExists))",
                confidence: 0.5,
                evidence: ["move_partial=true"]
            )
        }

        return failed(summary: "Move verification failed.", fileAction: "move", path: sourcePath, reason: "state_mismatch")
    }

    private static func pathExists(_ path: String) -> Bool? {
        switch DexterApprovedFilePathPolicy.evaluate(path: path) {
        case .approved(let url):
            return FileManager.default.fileExists(atPath: url.path)
        case .rejected:
            return nil
        }
    }

    private static func failed(
        summary: String,
        fileAction: String,
        path: String,
        reason: String
    ) -> DexterActionVerificationReport {
        DexterActionVerificationReport(
            status: .failed,
            summary: summary,
            expectedStateDescription: "File \(fileAction) at \(path) should meet Dexter verification rules.",
            observedStateDescription: reason,
            confidence: 0.88,
            evidence: ["file_verification_failed=true"],
            reason: reason
        )
    }
}
