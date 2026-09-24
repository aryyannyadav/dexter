//
//  DexterContextPacketBuilder.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterAvailableToolsCollector {
    @MainActor
    static func collect(registryGateway: DexterToolRegistryGateway = DexterToolRegistryGateway()) async -> DexterAvailableToolsContext {
        let definitions = await registryGateway.availableToolDefinitions()
        let descriptors = definitions.map { definition in
            DexterAvailableToolDescriptor(
                toolKindIdentifier: definition.name.rawValue,
                openClawCapability: definition.requiredOpenClawCapability?.rawValue,
                isAvailable: true
            )
        }

        return DexterAvailableToolsContext(
            tools: descriptors,
            availability: descriptors.isEmpty
                ? .unavailable(errorDescription: "No registered tools are available on this machine.")
                : .available
        )
    }
}

enum DexterBrowserContextCollector {
    static func collect(
        activeApplication: DexterActiveApplicationContext,
        activeWindow: DexterActiveWindowContext
    ) -> DexterBrowserContext {
        let applicationName = activeApplication.localizedName?.lowercased() ?? ""
        let isBrowserFrontmost = applicationName.contains("safari")
            || applicationName.contains("chrome")
            || applicationName.contains("firefox")
            || applicationName.contains("edge")

        guard isBrowserFrontmost else {
            return DexterBrowserContext(
                frontmostApplicationName: activeApplication.localizedName,
                inferredPageURL: nil,
                inferredPageTitle: nil,
                pageIdentity: nil,
                relevantTextSnippet: nil,
                selectedElementDescription: nil,
                availability: .notApplicable
            )
        }

        let browserState = DexterBrowserStateCollector.collect(
            activeApplication: activeApplication,
            activeWindow: activeWindow,
            selectedText: DexterSelectedTextContext(selectedText: nil, availability: .notApplicable),
            browserContext: nil,
            currentTaskDescription: nil,
            pointerSemanticTargetLabel: nil
        )

        return DexterBrowserContext(
            frontmostApplicationName: activeApplication.localizedName,
            inferredPageURL: browserState.url,
            inferredPageTitle: browserState.title ?? activeWindow.title,
            pageIdentity: browserState.pageIdentity,
            relevantTextSnippet: browserState.relevantText,
            selectedElementDescription: browserState.selectedElementDescription,
            availability: activeWindow.availability
        )
    }
}

enum DexterProjectContextCollector {
    static func collect(
        from persistentMemory: DexterPersistentMemoryContext,
        memoryStore: MemoryStore,
        authorizedInput: DexterAuthorizedPersonalContextInput
    ) -> DexterProjectContext {
        let workflowLabel = persistentMemory.workflowContext?.summary
        let notes = persistentMemory.rememberedFacts.map(\.content)
        let graph = DexterPersonalContextGraphBuilder.build(
            memoryStore: memoryStore,
            authorizedInput: authorizedInput
        )
        let crossApplicationContext = DexterCrossApplicationContextComposer.compose(
            graph: graph,
            authorizedInput: authorizedInput
        )
        let hasContent = workflowLabel != nil
            || !notes.isEmpty
            || !graph.entities.isEmpty
            || !crossApplicationContext.relationshipSummaries.isEmpty
        return DexterProjectContext(
            workflowLabel: workflowLabel,
            projectNotes: notes,
            personalContextGraph: graph,
            crossApplicationContext: crossApplicationContext,
            availability: hasContent ? .available : .notApplicable
        )
    }
}

enum DexterContextPacketLegacyMapper {
    static func legacyContext(from packet: DexterContextPacket) -> DexterContext {
        DexterContext(
            userMessage: DexterUserMessageContext(text: packet.userIntent.userMessage),
            pointer: packet.pointer,
            display: packet.display,
            screen: packet.screenContext ?? DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .notApplicable
            ),
            activeApplication: packet.activeApplication ?? DexterActiveApplicationContext(
                bundleIdentifier: nil,
                localizedName: nil,
                availability: .notApplicable
            ),
            activeWindow: packet.activeWindow ?? DexterActiveWindowContext(
                title: nil,
                availability: .notApplicable
            ),
            selectedText: packet.selectedText ?? DexterSelectedTextContext(
                selectedText: nil,
                availability: .notApplicable
            ),
            clipboard: packet.clipboard ?? DexterClipboardContext(
                stringValue: nil,
                inclusionReason: nil,
                availability: .notApplicable
            ),
            conversation: packet.conversation ?? DexterConversationContext(recentExchanges: []),
            recentActions: packet.recentActions ?? DexterActionHistoryContext(recentActions: []),
            currentTask: packet.currentTask ?? DexterTaskContext(currentTaskDescription: nil),
            persistentMemory: packet.memory ?? .empty,
            personalContextGraph: packet.projectContext?.personalContextGraph,
            crossApplicationContext: packet.projectContext?.crossApplicationContext,
            attention: packet.attention
        )
    }
}
