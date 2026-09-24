//
//  DexterPersonalContextIntegrations.swift
//  leanring-buddy
//
//  Legacy entry points — implementations live in `DexterIntegrationProviders`.
//

import Foundation

enum DexterPersonalContextIntegrationSource: String, Equatable {
    case visualStudioCode = "vscode"
    case browser = "browser"
    case documents = "documents"
    case terminal = "terminal"
    case gitHub = "github"
    case calendar = "calendar"
    case communication = "communication"
}

struct DexterPersonalContextIntegrationResult: Equatable {
    let entities: [DexterContextGraphEntity]
    let relationships: [DexterContextGraphRelationship]
    let sourceLabel: String
}

enum DexterPersonalContextIntegrations {
    static func visualStudioCodeIntegration(
        authorizedInput: DexterAuthorizedPersonalContextInput,
        workflowEntityIdentifier: String?
    ) -> DexterPersonalContextIntegrationResult? {
        VisualStudioCodeIntegrationProvider().contribute(
            context: DexterIntegrationProviderInput(
                authorizedInput: authorizedInput,
                linkage: DexterIntegrationLinkage(workflowEntityIdentifier: workflowEntityIdentifier)
            )
        )
    }

    static func browserIntegration(
        authorizedInput: DexterAuthorizedPersonalContextInput,
        workflowEntityIdentifier: String?
    ) -> DexterPersonalContextIntegrationResult? {
        BrowserIntegrationProvider().contribute(
            context: DexterIntegrationProviderInput(
                authorizedInput: authorizedInput,
                linkage: DexterIntegrationLinkage(workflowEntityIdentifier: workflowEntityIdentifier)
            )
        )
    }

    static func documentsIntegration(
        authorizedInput: DexterAuthorizedPersonalContextInput,
        projectEntityIdentifier: String?,
        taskEntityIdentifier: String?
    ) -> DexterPersonalContextIntegrationResult? {
        DocumentsIntegrationProvider().contribute(
            context: DexterIntegrationProviderInput(
                authorizedInput: authorizedInput,
                linkage: DexterIntegrationLinkage(
                    projectEntityIdentifier: projectEntityIdentifier,
                    taskEntityIdentifier: taskEntityIdentifier
                )
            )
        )
    }
}
