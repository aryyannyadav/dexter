//
//  DexterContextAssembler.swift
//  leanring-buddy
//
//  Context Engine: request-driven collection → ContextPacket → legacy DexterContext.
//

import AppKit
import Foundation

enum DexterScreenCaptureMode: Equatable {
    case captureAllDisplaysIfPermitted
    case captureCursorDisplayIfPermitted
    case useOverride([DexterScreenCaptureSnapshot])
    case skip
}

enum DexterContextPerformanceProfile: Equatable {
    case standard
    case minimal
}

struct DexterContextAssemblyRequest: Equatable {
    let userMessage: String
    let screenCaptureMode: DexterScreenCaptureMode
    let includeRecentConversation: Bool
    let recentConversationLimit: Int
    let hasPersistedScreenContentGrant: Bool
    let pointerLocationInScreenSpaceOverride: CGPoint?
    let performanceProfile: DexterContextPerformanceProfile

    init(
        userMessage: String,
        screenCaptureMode: DexterScreenCaptureMode = .captureAllDisplaysIfPermitted,
        includeRecentConversation: Bool = true,
        recentConversationLimit: Int = 8,
        hasPersistedScreenContentGrant: Bool = false,
        pointerLocationInScreenSpaceOverride: CGPoint? = nil,
        performanceProfile: DexterContextPerformanceProfile = .standard
    ) {
        self.userMessage = userMessage
        self.screenCaptureMode = screenCaptureMode
        self.includeRecentConversation = includeRecentConversation
        self.recentConversationLimit = recentConversationLimit
        self.hasPersistedScreenContentGrant = hasPersistedScreenContentGrant
        self.pointerLocationInScreenSpaceOverride = pointerLocationInScreenSpaceOverride
        self.performanceProfile = performanceProfile
    }
}

/// Assembles typed Dexter context at invocation time. Does not persist screenshots.
final class DexterContextAssembler {
    private let permissionManager: PermissionManager
    private let memoryStore: MemoryStore
    private let screenCaptureProvider: DexterScreenCaptureProviding
    private let actionHistoryStore: DexterActionHistoryStore
    private let taskStateStore: DexterTaskStateStore

    private(set) var lastAssemblyResult: DexterContextAssemblyResult?

    init(
        permissionManager: PermissionManager,
        memoryStore: MemoryStore,
        screenCaptureProvider: DexterScreenCaptureProviding,
        actionHistoryStore: DexterActionHistoryStore,
        taskStateStore: DexterTaskStateStore
    ) {
        self.permissionManager = permissionManager
        self.memoryStore = memoryStore
        self.screenCaptureProvider = screenCaptureProvider
        self.actionHistoryStore = actionHistoryStore
        self.taskStateStore = taskStateStore
    }

    func assembleContext(request: DexterContextAssemblyRequest) async -> DexterContext {
        let result = await assembleContextPacket(request: request)
        lastAssemblyResult = result
        return result.legacyContext
    }

    func assembleContextPacket(request: DexterContextAssemblyRequest) async -> DexterContextAssemblyResult {
        let collectionPlan = DexterContextCollectionPlanner.plan(for: request)
        var collectedSections: [DexterContextCollectedSection] = []
        var skippedSections: [DexterContextSkippedSection] = []

        func recordCollected(
            _ sectionName: String,
            relevanceLevel: DexterContextRelevanceLevel,
            priority: DexterContextPriority,
            detail: String
        ) {
            collectedSections.append(
                DexterContextCollectedSection(
                    sectionName: sectionName,
                    relevanceLevel: relevanceLevel,
                    priority: priority,
                    detail: detail
                )
            )
            DexterContextEngineLog.logCollected(
                sectionName: sectionName,
                relevanceLevel: relevanceLevel,
                priority: priority,
                detail: detail
            )
        }

        func recordSkipped(_ sectionName: String, reason: String) {
            skippedSections.append(DexterContextSkippedSection(sectionName: sectionName, reason: reason))
            DexterContextEngineLog.logSkipped(sectionName: sectionName, reason: reason)
        }

        let permissionSnapshot = permissionManager.currentPermissionSnapshot(
            hasPersistedScreenContentGrant: request.hasPersistedScreenContentGrant
        )

        let permissions: DexterContextPermissionSnapshot?
        if collectionPlan.collectPermissions {
            permissions = DexterContextPermissionSnapshot(
                hasScreenRecordingPermission: permissionSnapshot.hasScreenRecordingPermission,
                hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
                hasScreenContentPermission: permissionSnapshot.hasScreenContentPermission,
                hasMicrophonePermission: permissionSnapshot.hasMicrophonePermission
            )
            recordCollected(
                "permissions",
                relevanceLevel: .application,
                priority: .high,
                detail: "permission_flags_collected"
            )
        } else {
            permissions = nil
            recordSkipped("permissions", reason: "not required for minimum relevance \(collectionPlan.minimumRelevanceLevel.rawValue)")
        }

        let pointerLocationInScreenSpace: CGPoint?
        if collectionPlan.collectPointer {
            pointerLocationInScreenSpace = await MainActor.run {
                request.pointerLocationInScreenSpaceOverride ?? NSEvent.mouseLocation
            }
            recordCollected(
                "pointer",
                relevanceLevel: .region,
                priority: .high,
                detail: "pointer_location_collected"
            )
        } else {
            pointerLocationInScreenSpace = nil
            recordSkipped("pointer", reason: "minimum relevance does not include REGION")
        }

        let resolvedScreenContext: DexterScreenContext?
        if collectionPlan.collectScreenContext {
            let screenContext = await DexterPerformanceTiming.measure(bucket: .screenCapture) {
                await buildScreenContext(
                    screenCaptureMode: request.screenCaptureMode,
                    permissionSnapshot: permissionSnapshot,
                    pointerLocationInScreenSpace: pointerLocationInScreenSpace ?? .zero
                )
            }
            resolvedScreenContext = screenContext
            let imageCount = screenContext.allScreens.count
            recordCollected(
                "screenContext",
                relevanceLevel: .object,
                priority: .high,
                detail: "image_count=\(imageCount) availability=\(screenContext.captureAvailability)"
            )
        } else {
            resolvedScreenContext = nil
            recordSkipped("screenContext", reason: "request-driven capture not required for this turn")
        }

        let environmentContext: DexterEnvironmentCollectionResult?
        if collectionPlan.collectActiveApplication
            || collectionPlan.collectActiveWindow
            || collectionPlan.collectSelectedText {
            let pointerForEnvironment = pointerLocationInScreenSpace ?? .zero
            environmentContext = await Task.detached(priority: .userInitiated) {
                DexterEnvironmentContextCollector.collect(
                    hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
                    pointerLocationInScreenSpace: pointerForEnvironment
                )
            }.value
        } else {
            environmentContext = nil
        }

        let activeApplication: DexterActiveApplicationContext?
        if collectionPlan.collectActiveApplication, let environmentContext {
            activeApplication = environmentContext.activeApplication
            recordCollected(
                "activeApplication",
                relevanceLevel: .application,
                priority: .high,
                detail: "name_present=\(environmentContext.activeApplication.localizedName != nil)"
            )
        } else {
            activeApplication = nil
            recordSkipped("activeApplication", reason: "not required for minimum relevance \(collectionPlan.minimumRelevanceLevel.rawValue)")
        }

        let activeWindow: DexterActiveWindowContext?
        if collectionPlan.collectActiveWindow, let environmentContext {
            activeWindow = environmentContext.activeWindow
            recordCollected(
                "activeWindow",
                relevanceLevel: .window,
                priority: .high,
                detail: "title_present=\(environmentContext.activeWindow.title != nil)"
            )
        } else {
            activeWindow = nil
            recordSkipped("activeWindow", reason: "not required for minimum relevance \(collectionPlan.minimumRelevanceLevel.rawValue)")
        }

        let selectedText: DexterSelectedTextContext?
        if collectionPlan.collectSelectedText, let environmentContext {
            selectedText = environmentContext.selectedText
            recordCollected(
                "selectedText",
                relevanceLevel: .window,
                priority: .high,
                detail: "selection_present=\(environmentContext.selectedText.selectedText != nil)"
            )
        } else {
            selectedText = nil
            recordSkipped("selectedText", reason: "not required for this request class")
        }

        let accessibilityHint: DexterAccessibilityHintAtPointer?
        if collectionPlan.collectPointer, let pointerLocationInScreenSpace {
            accessibilityHint = await Task.detached(priority: .userInitiated) {
                DexterPointerAccessibilityHintCollector.collectHint(
                    hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
                    pointerLocationInScreenSpace: pointerLocationInScreenSpace
                )
            }.value
            recordCollected(
                "pointerAccessibility",
                relevanceLevel: .object,
                priority: .high,
                detail: "ax_hint_available=\(accessibilityHint?.availability == .available)"
            )
        } else {
            accessibilityHint = nil
            recordSkipped("pointerAccessibility", reason: "pointer not collected for this turn")
        }

        let attentionContext: DexterAttentionContext?
        if collectionPlan.collectPointer, let pointerLocationInScreenSpace {
            let screenForAttention = resolvedScreenContext ?? DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .notApplicable
            )
            attentionContext = DexterPointerAttentionCalculator.buildAttentionContext(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                display: environmentContext?.display,
                primaryScreenshot: screenForAttention.primaryScreenshot,
                accessibilityHintAtPointer: accessibilityHint
                    ?? DexterAccessibilityHintAtPointer(
                        roleDescription: nil,
                        title: nil,
                        valueDescription: nil,
                        availability: .notApplicable
                    )
            )
        } else {
            attentionContext = nil
        }

        let pointerContext: DexterPointerContext?
        let pointerTarget: DexterPointerTargetContext?
        if collectionPlan.collectPointer, let pointerLocationInScreenSpace, let attentionContext {
            let pipelineInput = DexterPointerIntelligencePipelineInput(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                capturedAt: Date(),
                display: environmentContext?.display,
                activeApplication: activeApplication,
                activeWindow: activeWindow,
                attentionContext: attentionContext,
                accessibilityHintAtPointer: accessibilityHint
                    ?? DexterAccessibilityHintAtPointer(
                        roleDescription: nil,
                        title: nil,
                        valueDescription: nil,
                        availability: .notApplicable
                    ),
                primaryScreenshot: resolvedScreenContext?.primaryScreenshot,
                elementLocationCorroboratesPointer: false,
                userMessage: request.userMessage
            )
            pointerContext = DexterPointerIntelligencePipeline.buildPointerContext(input: pipelineInput)
            if collectionPlan.collectPointerTarget {
                pointerTarget = DexterPointerIntelligencePipeline.buildPointerTargetContext(
                    from: pointerContext!,
                    accessibilityHintAtPointer: pipelineInput.accessibilityHintAtPointer
                )
                recordCollected(
                    "pointerSemanticTarget",
                    relevanceLevel: .object,
                    priority: .high,
                    detail: "confidence=\(String(format: "%.2f", pointerContext?.confidence ?? 0))"
                )
            } else {
                pointerTarget = nil
            }
        } else {
            pointerContext = nil
            pointerTarget = nil
        }

        let clipboard: DexterClipboardContext?
        if collectionPlan.collectClipboard {
            clipboard = buildClipboardContext(forUserMessage: request.userMessage)
            recordCollected(
                "clipboard",
                relevanceLevel: .window,
                priority: .medium,
                detail: "clipboard_included=\(clipboard?.stringValue != nil)"
            )
        } else {
            clipboard = nil
            recordSkipped("clipboard", reason: "user message did not request clipboard context")
        }

        let conversation: DexterConversationContext?
        if collectionPlan.collectConversation && request.includeRecentConversation {
            let allExchanges = memoryStore.recentExchanges(limit: request.recentConversationLimit)
            let packagedConversation = DexterConversationPackaging.package(allExchanges: allExchanges)
            conversation = DexterConversationContext(
                recentExchanges: packagedConversation.recentExchangesForPrompt,
                earlierSessionSummary: packagedConversation.earlierSessionSummary,
                apiHistoryExchanges: packagedConversation.recentExchangesForAPIHistory
            )
            recordCollected(
                "conversation",
                relevanceLevel: .user,
                priority: .high,
                detail: "prompt_exchanges=\(conversation?.recentExchanges.count ?? 0) api_exchanges=\(conversation?.apiHistoryExchanges.count ?? 0)"
            )
        } else {
            conversation = nil
            recordSkipped("conversation", reason: "conversation not included for this request")
        }

        let recentActions: DexterActionHistoryContext?
        if collectionPlan.collectRecentActions {
            recentActions = DexterActionHistoryContext(recentActions: actionHistoryStore.recentActions(limit: 10))
            recordCollected(
                "recentActions",
                relevanceLevel: .workflow,
                priority: .medium,
                detail: "action_count=\(recentActions?.recentActions.count ?? 0)"
            )
        } else {
            recentActions = nil
            recordSkipped("recentActions", reason: "workflow context not required")
        }

        let currentTask: DexterTaskContext?
        if collectionPlan.collectCurrentTask {
            currentTask = DexterTaskContext(
                currentTaskDescription: memoryStore.activeTaskDescription,
                activeWorkflowTask: taskStateStore.activeWorkflowTask,
                accountabilitySnapshot: memoryStore.accountabilityTaskSnapshot()
            )
            recordCollected(
                "currentTask",
                relevanceLevel: .workflow,
                priority: .medium,
                detail: "task_present=\(currentTask?.currentTaskDescription != nil || currentTask?.activeWorkflowTask != nil)"
            )
        } else {
            currentTask = nil
            recordSkipped("currentTask", reason: "workflow context not required")
        }

        let memory: DexterPersistentMemoryContext?
        if collectionPlan.collectMemory {
            let memoryLimit = DexterContextMemoryLimitPolicy.retrievalLimit(for: request)
            memory = memoryStore.persistentMemoryContext(forQuery: request.userMessage, limit: memoryLimit)
            recordCollected(
                "memory",
                relevanceLevel: .longTerm,
                priority: .medium,
                detail: "retrieved_memories=\(memory?.retrievedMemories.count ?? 0)"
            )
        } else {
            memory = nil
            recordSkipped("memory", reason: "long-term memory not required")
        }

        let browserContext: DexterBrowserContext?
        if collectionPlan.collectBrowserContext,
           let activeApplication,
           let activeWindow {
            browserContext = DexterBrowserContextCollector.collect(
                activeApplication: activeApplication,
                activeWindow: activeWindow
            )
            recordCollected(
                "browserContext",
                relevanceLevel: .window,
                priority: .medium,
                detail: "browser_applicable=\(browserContext?.availability != .notApplicable)"
            )
        } else {
            browserContext = nil
            recordSkipped("browserContext", reason: "browser context not required or environment not collected")
        }

        let availableTools: DexterAvailableToolsContext?
        if collectionPlan.collectAvailableTools {
            availableTools = await MainActor.run {
                DexterAvailableToolsCollector.collect()
            }
            let availableCount = availableTools?.tools.filter(\.isAvailable).count ?? 0
            recordCollected(
                "availableTools",
                relevanceLevel: .application,
                priority: .medium,
                detail: "available_tool_count=\(availableCount)"
            )
        } else {
            availableTools = nil
            recordSkipped("availableTools", reason: "tool availability not required for this request")
        }

        recordCollected(
            "userIntent",
            relevanceLevel: collectionPlan.minimumRelevanceLevel,
            priority: .high,
            detail: "message_length=\(request.userMessage.count)"
        )

        let projectContext: DexterProjectContext?
        if collectionPlan.collectProjectContext, let memory {
            let authorizedPersonalContextInput = DexterAuthorizedPersonalContextInput(
                activeApplicationName: activeApplication?.localizedName,
                activeApplicationBundleIdentifier: activeApplication?.bundleIdentifier,
                activeWindowTitle: activeWindow?.title,
                browserPageTitle: browserContext?.inferredPageTitle,
                browserPageURL: browserContext?.inferredPageURL,
                currentTaskDescription: currentTask?.currentTaskDescription,
                workflowSummary: memory.workflowContext?.summary,
                recentConversationExchanges: conversation?.recentExchanges ?? [],
                recentActionSummaries: recentActions?.recentActions.map(\.summary) ?? [],
                retrievedMemories: memory.retrievedMemories,
                accountabilityTasks: memoryStore.allAccountabilityTasks(),
                selectedTextSnippet: selectedText?.selectedText
            )
            projectContext = DexterProjectContextCollector.collect(
                from: memory,
                memoryStore: memoryStore,
                authorizedInput: authorizedPersonalContextInput
            )
            recordCollected(
                "projectContext",
                relevanceLevel: .project,
                priority: .medium,
                detail: "graph_entities=\(projectContext?.personalContextGraph?.entities.count ?? 0)"
            )
        } else {
            projectContext = nil
            recordSkipped("projectContext", reason: "project scope not required")
        }

        let packet = DexterContextPacket(
            userIntent: DexterUserIntentContext(
                userMessage: request.userMessage,
                minimumRelevanceLevel: collectionPlan.minimumRelevanceLevel
            ),
            activeApplication: activeApplication,
            activeWindow: activeWindow,
            display: environmentContext?.display,
            pointer: pointerContext,
            pointerTarget: pointerTarget,
            screenContext: resolvedScreenContext,
            selectedText: selectedText,
            clipboard: clipboard,
            memory: memory,
            conversation: conversation,
            currentTask: currentTask,
            recentActions: recentActions,
            availableTools: availableTools,
            permissions: permissions,
            projectContext: projectContext,
            browserContext: browserContext,
            attention: attentionContext
        )

        let diagnostics = DexterContextAssemblyDiagnostics(
            collectedSections: collectedSections,
            skippedSections: skippedSections
        )
        DexterContextEngineLog.logSummary(diagnostics: diagnostics)

        return DexterContextAssemblyResult(
            packet: packet,
            legacyContext: DexterContextPacketLegacyMapper.legacyContext(from: packet),
            diagnostics: diagnostics
        )
    }

    private func buildScreenContext(
        screenCaptureMode: DexterScreenCaptureMode,
        permissionSnapshot: DexterPermissionSnapshot,
        pointerLocationInScreenSpace: CGPoint
    ) async -> DexterScreenContext {
        switch screenCaptureMode {
        case .skip:
            return DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .notApplicable
            )

        case .useOverride(let overrideSnapshots):
            let primaryScreenshot = overrideSnapshots.first(where: { $0.isCursorScreen }) ?? overrideSnapshots.first
            return DexterScreenContext(
                primaryScreenshot: primaryScreenshot,
                allScreens: overrideSnapshots,
                captureAvailability: .available
            )

        case .captureAllDisplaysIfPermitted:
            return await captureScreensIfPermitted(
                permissionSnapshot: permissionSnapshot,
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                scope: .allDisplays
            )

        case .captureCursorDisplayIfPermitted:
            return await captureScreensIfPermitted(
                permissionSnapshot: permissionSnapshot,
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                scope: .cursorDisplayOnly
            )
        }
    }

    private func captureScreensIfPermitted(
        permissionSnapshot: DexterPermissionSnapshot,
        pointerLocationInScreenSpace: CGPoint,
        scope: DexterScreenCaptureScope
    ) async -> DexterScreenContext {
        guard permissionSnapshot.hasScreenRecordingPermission else {
            DexterDiagnosticLog.vision("screen capture skipped — Screen Recording permission missing")
            return DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .permissionMissing
            )
        }

        DexterDiagnosticLog.vision("screen capture started (scope: \(scope == .cursorDisplayOnly ? "cursor display" : "all displays"))")
        DexterVisionTiming.markCaptureStarted()
        do {
            let captureReason = "visual-request"
            let captures = try await DexterAsyncTimeout.withTimeout(seconds: 45) { [self] in
                try await captureScreensOnMainActor(
                    pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                    scope: scope,
                    diagnosticReason: captureReason
                )
            }
            DexterVisionTiming.markCaptureCompleted()
            DexterDiagnosticLog.vision("screen capture finished (\(captures.count) image(s))")
            DexterScreenCaptureDiagnostics.logCaptureComplete(reason: captureReason, imageCount: captures.count)
            DexterTurnTrace.log("screenshot captured (\(captures.count) image(s))")
            let snapshots = captures.map { DexterScreenCaptureSnapshot(companionScreenCapture: $0) }
            let primaryScreenshot = snapshots.first(where: { $0.isCursorScreen }) ?? snapshots.first
            return DexterScreenContext(
                primaryScreenshot: primaryScreenshot,
                allScreens: snapshots,
                captureAvailability: .available
            )
        } catch is DexterModelRequestTimeoutError {
            DexterDiagnosticLog.vision("screen capture timed out")
            return DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .unavailable(errorDescription: "Screen capture timed out")
            )
        } catch {
            DexterDiagnosticLog.vision("screen capture failed")
            return DexterScreenContext(
                primaryScreenshot: nil,
                allScreens: [],
                captureAvailability: .unavailable(errorDescription: error.localizedDescription)
            )
        }
    }

    private func captureScreensOnMainActor(
        pointerLocationInScreenSpace: CGPoint,
        scope: DexterScreenCaptureScope,
        diagnosticReason: String
    ) async throws -> [CompanionScreenCapture] {
        if Thread.isMainThread {
            return try await screenCaptureProvider.captureScreensForPointerAttention(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                scope: scope,
                diagnosticReason: diagnosticReason
            )
        }

        return try await Task { @MainActor in
            try await screenCaptureProvider.captureScreensForPointerAttention(
                pointerLocationInScreenSpace: pointerLocationInScreenSpace,
                scope: scope,
                diagnosticReason: diagnosticReason
            )
        }.value
    }

    private func buildClipboardContext(forUserMessage userMessage: String) -> DexterClipboardContext {
        guard DexterClipboardContextEvaluator.shouldIncludeClipboard(forUserMessage: userMessage) else {
            return DexterClipboardContext(
                stringValue: nil,
                inclusionReason: nil,
                availability: .notApplicable
            )
        }

        let clipboardString = DexterClipboardContextEvaluator.readClipboardStringForContext()
        return DexterClipboardContext(
            stringValue: clipboardString,
            inclusionReason: .userMessageMentionedClipboard,
            availability: .available
        )
    }
}
