//
//  DexterOpenClawStructuredFailureParser.swift
//  leanring-buddy
//

import Foundation

enum DexterOpenClawStructuredFailureParser {
    static func failureCode(fromMessage message: String, rawOutput: String?) -> DexterOpenClawStructuredFailureCode? {
        if let rawOutput, let code = parseCode(fromJSONText: rawOutput) {
            return code
        }
        return parseCode(fromJSONText: message)
    }

    private static func parseCode(fromJSONText text: String) -> DexterOpenClawStructuredFailureCode? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let codeString = object["code"] as? String,
               let code = DexterOpenClawStructuredFailureCode(rawValue: codeString) {
                return code
            }
            if let errorObject = object["error"] as? [String: Any],
               let codeString = errorObject["code"] as? String,
               let code = DexterOpenClawStructuredFailureCode(rawValue: codeString) {
                return code
            }
        }

        for code in DexterOpenClawStructuredFailureCode.allCases {
            if trimmed.contains(code.rawValue) {
                return code
            }
        }
        return nil
    }
}

enum DexterOpenClawExecutionFailureMessage {
    static func userFacingMessage(
        actionRequest: AgentActionRequest,
        gatewayMessage: String,
        structuredFailureCode: DexterOpenClawStructuredFailureCode?
    ) -> String {
        let sanitizedGatewayMessage = gatewayMessage.nonEmptyTrimmedValue
        if let structuredFailureCode {
            let structuredMessage = DexterOpenClawUserFacingFailure.message(
                for: structuredFailureCode,
                detail: sanitizedGatewayMessage
            )
            return lifecycleFailureMessage(
                actionRequest: actionRequest,
                structuredMessage: structuredMessage
            )
        }

        if let sanitizedGatewayMessage {
            return lifecycleFailureMessage(
                actionRequest: actionRequest,
                structuredMessage: sanitizedGatewayMessage
            )
        }

        return lifecycleFailureMessage(
            actionRequest: actionRequest,
            structuredMessage: "The computer action failed."
        )
    }

    private static func lifecycleFailureMessage(
        actionRequest: AgentActionRequest,
        structuredMessage: String
    ) -> String {
        let applicationName = actionRequest.parameters["applicationName"]?.nonEmptyTrimmedValue
        switch actionRequest.actionIdentifier {
        case DexterActionType.openApplication.rawValue:
            if let applicationName {
                return "I couldn't open \(applicationName) because the computer action failed. \(structuredMessage) Nothing was marked complete."
            }
            return "I couldn't open that application because the computer action failed. \(structuredMessage) Nothing was marked complete."
        case DexterActionType.quitApplication.rawValue:
            if let applicationName {
                return "I couldn't quit \(applicationName) because the computer action failed. \(structuredMessage) Nothing was marked complete."
            }
            return "I couldn't quit that application because the computer action failed. \(structuredMessage) Nothing was marked complete."
        case DexterActionType.focusApplication.rawValue:
            if let applicationName {
                return "I couldn't focus \(applicationName) because the computer action failed. \(structuredMessage) Nothing was marked complete."
            }
            return "I couldn't focus that application because the computer action failed. \(structuredMessage) Nothing was marked complete."
        default:
            return "\(structuredMessage) Nothing was marked complete."
        }
    }
}
