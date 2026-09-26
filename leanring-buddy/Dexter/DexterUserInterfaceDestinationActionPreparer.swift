//
//  DexterUserInterfaceDestinationActionPreparer.swift
//  leanring-buddy
//

import CoreGraphics
import Foundation

enum DexterUserInterfaceDestinationPreparationFailure: Equatable, Error {
    case targetResolutionFailed(destinationLabel: String, applicationName: String?, detail: String)
}

enum DexterUserInterfaceDestinationActionPreparer {
    static func isSemanticUserInterfaceDestinationAction(_ action: DexterAction) -> Bool {
        if action.type == .navigate,
           action.parameters["uiDestination"]?.nonEmptyTrimmedValue != nil {
            return true
        }
        if action.type == .click,
           action.parameters["elementRef"]?.nonEmptyTrimmedValue != nil,
           action.parameters["x"] == nil,
           action.parameters["y"] == nil {
            return true
        }
        return false
    }

    @MainActor
    static func prepareResolvedClickAction(
        proposedAction: DexterAction,
        dexterContext: DexterContext,
        permissionManager: PermissionManager,
        hasPersistedScreenContentGrant: Bool,
        contextObserver: DexterActionContextObserver,
        visionProvider: VisionProvider?
    ) async -> Swift.Result<DexterAction, DexterUserInterfaceDestinationPreparationFailure> {
        let destinationLabel = proposedAction.parameters["uiDestination"]?.nonEmptyTrimmedValue
            ?? proposedAction.parameters["elementRef"]?.nonEmptyTrimmedValue
        guard let destinationLabel else {
            return .failure(
                .targetResolutionFailed(
                    destinationLabel: "the destination",
                    applicationName: proposedAction.parameters["parentApplicationName"],
                    detail: "Missing UI destination label."
                )
            )
        }

        let parentApplicationName = proposedAction.parameters["parentApplicationName"]?.nonEmptyTrimmedValue
            ?? proposedAction.parameters["applicationName"]?.nonEmptyTrimmedValue

        DexterActionDiagnosticLog.plan(
            "step=navigate application=\(parentApplicationName ?? "frontmost") target=\(destinationLabel)"
        )

        let observationIdentifier = String(proposedAction.parameters["targetObservationId"]?.nonEmptyTrimmedValue?.prefix(8) ?? UUID().uuidString.prefix(8))

        let permissionSnapshot = permissionManager.currentPermissionSnapshot(
            hasPersistedScreenContentGrant: hasPersistedScreenContentGrant
        )

        _ = contextObserver.observeCurrentEnvironment(
            pointerLocationInScreenSpace: .zero,
            hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission
        )

        DexterObservabilityLog.computer("phase=RESOLVING_TARGET")

        let resolutionInput = DexterUserInterfaceDestinationTargetResolutionInput(
            destinationLabel: destinationLabel,
            parentApplicationName: parentApplicationName,
            dexterContext: dexterContext,
            observationId: observationIdentifier,
            hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission
        )

        guard let resolvedTarget = await DexterUserInterfaceDestinationTargetResolver.resolve(
            input: resolutionInput,
            visionProvider: visionProvider
        ) else {
            DexterActionDiagnosticLog.action("target=\(destinationLabel) resolved=false")
            DexterObservabilityLog.error("type=TARGET_RESOLUTION_FAILED")
            let applicationPhrase = parentApplicationName.map { " in \($0)" } ?? ""
            return .failure(
                .targetResolutionFailed(
                    destinationLabel: destinationLabel,
                    applicationName: parentApplicationName,
                    detail: "Couldn't locate \(destinationLabel)\(applicationPhrase)."
                )
            )
        }

        if let center = resolvedTarget.centerInScreenSpace {
            return .success(
                resolvedClickAction(
                    from: proposedAction,
                    destinationLabel: destinationLabel,
                    parentApplicationName: parentApplicationName,
                    centerInScreenSpace: center,
                    elementRef: resolvedTarget.elementRef ?? destinationLabel,
                    resolutionSource: resolvedTarget.resolutionSource,
                    observationId: resolvedTarget.observationId
                )
            )
        }

        if let elementRef = resolvedTarget.elementRef?.nonEmptyTrimmedValue {
            var parameters = proposedAction.parameters
            parameters["elementRef"] = elementRef
            parameters["uiDestination"] = destinationLabel
            parameters["verificationHint"] = destinationLabel
            parameters["targetObservationId"] = resolvedTarget.observationId
            parameters["resolutionSource"] = resolvedTarget.resolutionSource.rawValue
            if let parentApplicationName {
                parameters["parentApplicationName"] = parentApplicationName
            }
            parameters.removeValue(forKey: "computerNavigation")
            parameters.removeValue(forKey: "applicationName")
            DexterObservabilityLog.target(
                "application=\(parentApplicationName ?? "frontmost") target=\(destinationLabel) resolved=true targetType=element resolutionSource=\(resolvedTarget.resolutionSource.rawValue)"
            )
            return .success(
                DexterAction(
                    id: proposedAction.id,
                    type: .click,
                    parameters: parameters,
                    riskLevel: proposedAction.riskLevel,
                    humanReadableDescription: proposedAction.humanReadableDescription,
                    state: proposedAction.state,
                    proposedAt: proposedAction.proposedAt,
                    updatedAt: Date()
                )
            )
        }

        DexterActionDiagnosticLog.action("target=\(destinationLabel) resolved=false")
        DexterObservabilityLog.error("type=TARGET_RESOLUTION_FAILED")
        let applicationPhrase = parentApplicationName.map { " in \($0)" } ?? ""
        return .failure(
            .targetResolutionFailed(
                destinationLabel: destinationLabel,
                applicationName: parentApplicationName,
                detail: "Couldn't locate \(destinationLabel)\(applicationPhrase)."
            )
        )
    }

    private static func resolvedClickAction(
        from proposedAction: DexterAction,
        destinationLabel: String,
        parentApplicationName: String?,
        centerInScreenSpace: CGPoint,
        elementRef: String,
        resolutionSource: DexterUserInterfaceDestinationResolutionSource,
        observationId: String
    ) -> DexterAction {
        DexterObservabilityLog.target(
            "application=\(parentApplicationName ?? "frontmost") target=\(destinationLabel) resolved=true targetType=coordinate resolutionSource=\(resolutionSource.rawValue) observationId=\(observationId)"
        )
        DexterActionDiagnosticLog.action(
            "target=\(destinationLabel) resolved=true coordinates=\(Int(centerInScreenSpace.x)),\(Int(centerInScreenSpace.y))"
        )
        var parameters = proposedAction.parameters
        parameters["elementRef"] = elementRef
        parameters["uiDestination"] = destinationLabel
        parameters["x"] = String(format: "%.0f", centerInScreenSpace.x)
        parameters["y"] = String(format: "%.0f", centerInScreenSpace.y)
        parameters["verificationHint"] = destinationLabel
        parameters["targetObservationId"] = observationId
        parameters["resolutionSource"] = resolutionSource.rawValue
        if let parentApplicationName {
            parameters["parentApplicationName"] = parentApplicationName
        }
        parameters.removeValue(forKey: "computerNavigation")
        parameters.removeValue(forKey: "applicationName")

        return DexterAction(
            id: proposedAction.id,
            type: .click,
            parameters: parameters,
            riskLevel: proposedAction.riskLevel,
            humanReadableDescription: proposedAction.humanReadableDescription,
            state: proposedAction.state,
            proposedAt: proposedAction.proposedAt,
            updatedAt: Date()
        )
    }

    static func userFacingMessage(for failure: DexterUserInterfaceDestinationPreparationFailure) -> String {
        switch failure {
        case .targetResolutionFailed(let destinationLabel, let applicationName, _):
            if let applicationName {
                return "I couldn't locate \(destinationLabel) in \(applicationName). Make sure that window is visible, then try again."
            }
            return "I couldn't locate \(destinationLabel) in the current window. Make sure it's visible, then try again."
        }
    }
}
