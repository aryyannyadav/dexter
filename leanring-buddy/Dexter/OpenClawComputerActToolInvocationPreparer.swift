//
//  OpenClawComputerActToolInvocationPreparer.swift
//  leanring-buddy
//

import Foundation

enum OpenClawComputerActToolInvocationPreparer {
    static func prepareIfNeeded(
        toolInvocation: DexterToolInvocation,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot,
        executionIdentifier: String,
        nodeInvokeClient: OpenClawNodeInvoking
    ) async throws -> DexterToolInvocation {
        guard requiresFreshObservationFrame(toolInvocation: toolInvocation) else {
            return toolInvocation
        }
        guard nodeSnapshot.hasScreenSnapshotCommand else {
            return toolInvocation
        }

        let snapshotParametersJSON = OpenClawNodeParametersJSONBuilder.payload(
            executionIdentifier: executionIdentifier,
            fields: [:]
        )

        let snapshotResult = try await nodeInvokeClient.invoke(
            nodeIdentifier: nodeSnapshot.nodeIdentifier,
            command: DexterOpenClawCapabilityKind.screenSnapshot.rawValue,
            parametersJSON: snapshotParametersJSON,
            invokeTimeoutMilliseconds: OpenClawNodeInvokeTimeouts.defaultInvokeTimeoutMilliseconds
        )

        guard snapshotResult.ok else {
            let failureMessage = snapshotResult.errorMessage
                ?? snapshotResult.combinedOutput.nonEmptyTrimmedValue
                ?? "screen.snapshot failed before computer.act."
            throw OpenClawComputerActPreparationError.snapshotFailed(failureMessage)
        }

        guard let frameMetadata = OpenClawScreenSnapshotFrameMetadataParser.parse(from: snapshotResult.combinedOutput) else {
            throw OpenClawComputerActPreparationError.missingFrameMetadata
        }

        var mergedParameters = toolInvocation.parameters
        if mergedParameters["displayFrameId"] == nil {
            if let displayFrameId = frameMetadata.displayFrameId ?? frameMetadata.frameId {
                mergedParameters["displayFrameId"] = displayFrameId
            }
        }
        if mergedParameters["observationId"] == nil, let observationId = frameMetadata.observationId {
            mergedParameters["observationId"] = observationId
        }
        if mergedParameters["refWidth"] == nil, let refWidth = frameMetadata.refWidth {
            mergedParameters["refWidth"] = String(refWidth)
        }

        return DexterToolInvocation(
            registeredToolName: toolInvocation.registeredToolName,
            toolKind: toolInvocation.toolKind,
            actionIdentifier: toolInvocation.actionIdentifier,
            parameters: mergedParameters
        )
    }

    private static func requiresFreshObservationFrame(toolInvocation: DexterToolInvocation) -> Bool {
        switch toolInvocation.toolKind {
        case .click, .scroll:
            let hasFrameBinding = toolInvocation.parameters["displayFrameId"]?.nonEmptyTrimmedValue != nil
                || toolInvocation.parameters["observationId"]?.nonEmptyTrimmedValue != nil
            return !hasFrameBinding
        default:
            return false
        }
    }
}

enum OpenClawComputerActPreparationError: Error, Equatable {
    case snapshotFailed(String)
    case missingFrameMetadata
}

extension OpenClawComputerActPreparationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .snapshotFailed(let message):
            return message
        case .missingFrameMetadata:
            return "OpenClaw returned a screenshot without frame metadata."
        }
    }
}
