//
//  DexterOpenClawApplicationLifecycleTests.swift
//  leanring-buddyTests
//

import Foundation
import Testing
@testable import leanring_buddy

struct DexterOpenClawApplicationLifecycleTests {
    private static let fullLifecycleDescriptor = OpenClawNodeComputerUseDescriptorSnapshot(
        providerIdentifier: "peekaboo",
        providerLabel: "Peekaboo",
        contractVersion: 2,
        advertisedActions: OpenClawNodeComputerUseDescriptorSnapshot.dexterMappedComputerUseActions
    )

    private static let computerActOnlyDescriptor = OpenClawNodeComputerUseDescriptorSnapshot(
        providerIdentifier: "minimal",
        providerLabel: "Minimal Provider",
        contractVersion: 2,
        advertisedActions: ["left_click", "type"]
    )

    @Test func lifecycleCapabilitiesRequireAdvertisedProviderActions() {
        #expect(
            DexterOpenClawApplicationLifecycleCapabilities.supportsToolExecution(
                toolKind: .launchApplication,
                computerUseDescriptor: fullLifecycleDescriptor
            )
        )
        #expect(
            !DexterOpenClawApplicationLifecycleCapabilities.supportsToolExecution(
                toolKind: .launchApplication,
                computerUseDescriptor: computerActOnlyDescriptor
            )
        )
        #expect(
            DexterOpenClawApplicationLifecycleCapabilities.unavailableReason(
                toolKind: .quitApplication,
                computerUseDescriptor: computerActOnlyDescriptor
            ) == .applicationLifecycleControlUnavailable(providerLabel: "Minimal Provider")
        )
    }

    @Test func applicationReferenceResolverRecognizesKnownBundleIdentifiers() {
        let safari = DexterApplicationReferenceResolver.resolve(userInput: "com.apple.Safari")
        #expect(safari.bundleIdentifier == "com.apple.Safari")

        let calculator = DexterApplicationReferenceResolver.resolve(userInput: "com.apple.calculator")
        #expect(calculator.bundleIdentifier == "com.apple.calculator")

        let whatsApp = DexterApplicationReferenceResolver.resolve(userInput: "net.whatsapp.WhatsApp")
        #expect(whatsApp.bundleIdentifier == "net.whatsapp.WhatsApp")

        let visualStudioCode = DexterApplicationReferenceResolver.resolve(userInput: "com.microsoft.VSCode")
        #expect(visualStudioCode.bundleIdentifier == "com.microsoft.VSCode")
    }

    @Test func applicationReferenceResolverMatchesBundleIdentifiersForDisplayNames() {
        #expect(
            DexterApplicationReferenceResolver.bundleIdentifierMatches(
                userInput: "Safari",
                bundleIdentifier: "com.apple.Safari"
            )
        )
        #expect(
            DexterApplicationReferenceResolver.bundleIdentifierMatches(
                userInput: "Calculator",
                bundleIdentifier: "com.apple.calculator"
            )
        )
        #expect(
            DexterApplicationReferenceResolver.bundleIdentifierMatches(
                userInput: "WhatsApp",
                bundleIdentifier: "net.whatsapp.WhatsApp"
            )
        )
        #expect(
            DexterApplicationReferenceResolver.bundleIdentifierMatches(
                userInput: "com.microsoft.VSCode",
                bundleIdentifier: "com.microsoft.VSCode"
            )
        )
    }

    @Test func invokePlannerMapsLifecycleToolsToAdvertisedComputerUseActions() {
        let executionIdentifier = "a1b2c3d4-e5f6-4789-abcd-ef0123456789"
        let enrichedLaunch = DexterApplicationLifecycleToolInvocationEnricher.enrich(
            DexterToolInvocation(
                toolKind: .launchApplication,
                actionIdentifier: DexterActionType.openApplication.rawValue,
                parameters: ["applicationName": "Safari"]
            )
        )

        let advertisedCommands = ["computer.act"]
        let launchPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: enrichedLaunch,
            executionIdentifier: executionIdentifier,
            computerUseDescriptor: fullLifecycleDescriptor,
            advertisedCommands: advertisedCommands
        )
        #expect(launchPlan?.parametersJSON.contains("\"action\":\"launch_app\"") == true)

        let listPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: DexterToolInvocation(
                toolKind: .listRunningApplications,
                actionIdentifier: DexterActionType.listRunningApplications.rawValue,
                parameters: [:]
            ),
            executionIdentifier: executionIdentifier,
            computerUseDescriptor: fullLifecycleDescriptor,
            advertisedCommands: advertisedCommands
        )
        #expect(listPlan?.parametersJSON.contains("\"action\":\"list_apps\"") == true)

        let missingKillPlan = OpenClawDexterToolInvokePlanner.plan(
            toolInvocation: DexterToolInvocation(
                toolKind: .quitApplication,
                actionIdentifier: DexterActionType.quitApplication.rawValue,
                parameters: ["applicationName": "Safari"]
            ),
            executionIdentifier: executionIdentifier,
            computerUseDescriptor: computerActOnlyDescriptor,
            advertisedCommands: advertisedCommands
        )
        #expect(missingKillPlan == nil)
    }

    @Test func toolRegistryHidesLifecycleToolsWhenProviderActionsMissing() {
        let discoveryReport = DexterOpenClawCapabilityDiscoveryReport(
            gatewayConnected: true,
            nodePaired: true,
            nodeConnected: true,
            nodeIdentifier: "node-1",
            capabilities: [
                DexterOpenClawCapabilityStatus(
                    capability: .computerAct,
                    isAvailable: true,
                    detail: "Available"
                )
            ],
            computerUseDescriptor: computerActOnlyDescriptor
        )
        let context = DexterToolRegistryAvailabilityContext(
            discoveryReport: discoveryReport,
            hasScreenRecordingPermission: true,
            hasAccessibilityPermission: true,
            isOpenClawInstalled: true
        )
        let launchDefinition = DexterToolRegistryCatalog.definition(for: DexterRegisteredToolName.applicationLaunch.rawValue)!
        #expect(!DexterToolRegistry.isAvailable(launchDefinition, context: context))
    }

    @Test func listRunningApplicationsIntentIsParsed() {
        #expect(
            DexterApplicationLifecycleIntentParser.matchesListRunningApplicationsIntent(
                normalizedUserMessage: "what apps are running"
            )
        )
    }
}
