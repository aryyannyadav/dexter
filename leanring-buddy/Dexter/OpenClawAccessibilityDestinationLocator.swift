//
//  OpenClawAccessibilityDestinationLocator.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

/// Resolves semantic UI labels through OpenClaw computer.act when the provider advertises accessibility/window APIs.
enum OpenClawAccessibilityDestinationLocator {
    struct ResolvedTarget: Equatable {
        let centerInScreenSpace: CGPoint?
        let elementRef: String?
    }

    @MainActor
    static func resolve(
        destinationLabel: String,
        parentApplicationName: String?,
        nodeInvokeClient: OpenClawNodeInvoking = OpenClawNodeInvokeClient()
    ) async -> ResolvedTarget? {
        let healthMonitor = OpenClawGatewayHealthMonitor.shared
        let nodeSnapshot = healthMonitor.preferredNodeSnapshot
        guard nodeSnapshot.isConnected else { return nil }

        let descriptor = nodeSnapshot.computerUseDescriptor
        let normalizedDestination = destinationLabel.lowercased()

        if descriptor.advertisesComputerUseAction("get_accessibility_tree") {
            if let match = await invokeComputerActAndFindLabel(
                actionName: "get_accessibility_tree",
                destinationLabel: normalizedDestination,
                parentApplicationName: parentApplicationName,
                nodeSnapshot: nodeSnapshot,
                nodeInvokeClient: nodeInvokeClient
            ) {
                return match
            }
        }

        if descriptor.advertisesComputerUseAction("get_window_state") {
            if let match = await invokeComputerActAndFindLabel(
                actionName: "get_window_state",
                destinationLabel: normalizedDestination,
                parentApplicationName: parentApplicationName,
                nodeSnapshot: nodeSnapshot,
                nodeInvokeClient: nodeInvokeClient
            ) {
                return match
            }
        }

        return nil
    }

    @MainActor
    private static func invokeComputerActAndFindLabel(
        actionName: String,
        destinationLabel: String,
        parentApplicationName: String?,
        nodeSnapshot: OpenClawNodeCapabilitySnapshot,
        nodeInvokeClient: OpenClawNodeInvoking
    ) async -> ResolvedTarget? {
        let executionIdentifier = UUID().uuidString
        var fields: [String: OpenClawComputerActJSONValue] = [:]
        if let parentApplicationName {
            fields["app"] = .string(parentApplicationName)
        }

        let parametersJSON = OpenClawComputerActRequestBuilder.computerActParametersJSON(
            executionIdentifier: executionIdentifier,
            actionName: actionName,
            fields: fields
        )

        do {
            let invokeResult = try await nodeInvokeClient.invoke(
                nodeIdentifier: nodeSnapshot.nodeIdentifier,
                command: DexterOpenClawCapabilityKind.computerAct.rawValue,
                parametersJSON: parametersJSON,
                invokeTimeoutMilliseconds: OpenClawNodeInvokeTimeouts.defaultInvokeTimeoutMilliseconds
            )
            guard invokeResult.ok else { return nil }
            return parseResolvedTarget(
                from: invokeResult.combinedOutput,
                destinationLabel: destinationLabel
            )
        } catch {
            return nil
        }
    }

    private static func parseResolvedTarget(
        from combinedOutput: String,
        destinationLabel: String
    ) -> ResolvedTarget? {
        let loweredOutput = combinedOutput.lowercased()
        guard loweredOutput.contains(destinationLabel) else { return nil }

        if let elementRef = extractJSONStringField(named: "elementRef", from: combinedOutput)
            ?? extractJSONStringField(named: "ref", from: combinedOutput) {
            return ResolvedTarget(centerInScreenSpace: nil, elementRef: elementRef)
        }

        if let x = extractJSONNumberField(named: "x", from: combinedOutput),
           let y = extractJSONNumberField(named: "y", from: combinedOutput) {
            return ResolvedTarget(
                centerInScreenSpace: CGPoint(x: x, y: y),
                elementRef: nil
            )
        }

        return nil
    }

    private static func extractJSONStringField(named fieldName: String, from text: String) -> String? {
        let pattern = "\"\(fieldName)\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func extractJSONNumberField(named fieldName: String, from text: String) -> Double? {
        let pattern = "\"\(fieldName)\"\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[range])
    }
}
