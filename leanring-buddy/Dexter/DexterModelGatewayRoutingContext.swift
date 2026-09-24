//
//  DexterModelGatewayRoutingContext.swift
//  leanring-buddy
//

import Foundation

struct DexterModelGatewayRoutingContext: Equatable {
    var intentComplexity: DexterIntentComplexity
    var prefersLocalPrivateProcessing: Bool
    var requiresVision: Bool
    var preferredCloudModelIdentifier: String?

    static func inferred(
        from request: DexterModelGenerationRequest,
        intentComplexity: DexterIntentComplexity,
        userMessage: String,
        prefersLocalProcessingSetting: Bool,
        preferredCloudModelIdentifier: String?
    ) -> DexterModelGatewayRoutingContext {
        let requiresVision = request.visionRequest != nil
            || !request.images.isEmpty
            || (request.userRequestedScreenContext && request.screenCaptureAvailability == .available)

        let prefersLocal = prefersLocalProcessingSetting
            || DexterModelGatewayRouter.userRequestedLocalPrivateProcessing(userMessage: userMessage)

        return DexterModelGatewayRoutingContext(
            intentComplexity: intentComplexity,
            prefersLocalPrivateProcessing: prefersLocal,
            requiresVision: requiresVision,
            preferredCloudModelIdentifier: preferredCloudModelIdentifier
        )
    }
}
