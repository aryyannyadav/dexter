//
//  DexterContextAssembler.swift
//  leanring-buddy
//

import AppKit
import Foundation

enum DexterScreenCaptureMode: Equatable {
    case captureAllDisplaysIfPermitted
    case captureCursorDisplayIfPermitted
    case useOverride([DexterScreenCaptureSnapshot])
    case skip
}

struct DexterContextAssemblyRequest: Equatable {
    let userMessage: String
    let screenCaptureMode: DexterScreenCaptureMode
    let includeRecentConversation: Bool
    let recentConversationLimit: Int
    let hasPersistedScreenContentGrant: Bool
    let pointerLocationInScreenSpaceOverride: CGPoint?

    init(
        userMessage: String,
        screenCaptureMode: DexterScreenCaptureMode = .captureAllDisplaysIfPermitted,
        includeRecentConversation: Bool = true,
        recentConversationLimit: Int = 10,
        hasPersistedScreenContentGrant: Bool = false,
        pointerLocationInScreenSpaceOverride: CGPoint? = nil
    ) {
        self.userMessage = userMessage
        self.screenCaptureMode = screenCaptureMode
        self.includeRecentConversation = includeRecentConversation
        self.recentConversationLimit = recentConversationLimit
        self.hasPersistedScreenContentGrant = hasPersistedScreenContentGrant
        self.pointerLocationInScreenSpaceOverride = pointerLocationInScreenSpaceOverride
    }
}

/// Assembles typed Dexter context at invocation time. Does not persist screenshots.
final class DexterContextAssembler {
    private let permissionManager: PermissionManager
    private let memoryStore: MemoryStore
    private let screenCaptureProvider: DexterScreenCaptureProviding
    private let actionHistoryStore: DexterActionHistoryStore
    private let taskStateStore: DexterTaskStateStore

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

    /// Builds context asynchronously. Screen capture and AX work run off the caller's critical path where possible.
    func assembleContext(request: DexterContextAssemblyRequest) async -> DexterContext {
        let permissionSnapshot = permissionManager.currentPermissionSnapshot(
            hasPersistedScreenContentGrant: request.hasPersistedScreenContentGrant
        )

        let pointerLocationInScreenSpace = await MainActor.run {
            request.pointerLocationInScreenSpaceOverride ?? NSEvent.mouseLocation
        }

        async let screenContext = buildScreenContext(
            screenCaptureMode: request.screenCaptureMode,
            permissionSnapshot: permissionSnapshot,
            pointerLocationInScreenSpace: pointerLocationInScreenSpace
        )

        async let environmentContext = Task.detached(priority: .userInitiated) {
            DexterEnvironmentContextCollector.collect(
                hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
                pointerLocationInScreenSpace: pointerLocationInScreenSpace
            )
        }.value

        async let accessibilityHintAtPointer = Task.detached(priority: .userInitiated) {
            DexterPointerAccessibilityHintCollector.collectHint(
                hasAccessibilityPermission: permissionSnapshot.hasAccessibilityPermission,
                pointerLocationInScreenSpace: pointerLocationInScreenSpace
            )
        }.value

        let resolvedScreenContext = await screenContext
        let resolvedEnvironmentContext = await environmentContext
        let resolvedAccessibilityHint = await accessibilityHintAtPointer

        let attentionContext = DexterPointerAttentionCalculator.buildAttentionContext(
            pointerLocationInScreenSpace: pointerLocationInScreenSpace,
            display: resolvedEnvironmentContext.display,
            primaryScreenshot: resolvedScreenContext.primaryScreenshot,
            accessibilityHintAtPointer: resolvedAccessibilityHint
        )

        let clipboardContext = buildClipboardContext(forUserMessage: request.userMessage)

        let conversationExchanges: [DexterConversationExchange]
        if request.includeRecentConversation {
            conversationExchanges = memoryStore.recentExchanges(limit: request.recentConversationLimit)
        } else {
            conversationExchanges = []
        }

        let recentActions = actionHistoryStore.recentActions(limit: 10)

        return DexterContext(
            userMessage: DexterUserMessageContext(text: request.userMessage),
            pointer: DexterPointerContext(locationInScreenSpace: pointerLocationInScreenSpace),
            display: resolvedEnvironmentContext.display,
            screen: resolvedScreenContext,
            activeApplication: resolvedEnvironmentContext.activeApplication,
            activeWindow: resolvedEnvironmentContext.activeWindow,
            selectedText: resolvedEnvironmentContext.selectedText,
            clipboard: clipboardContext,
            conversation: DexterConversationContext(recentExchanges: conversationExchanges),
            recentActions: DexterActionHistoryContext(recentActions: recentActions),
            currentTask: DexterTaskContext(
                currentTaskDescription: memoryStore.activeTaskDescription,
                activeWorkflowTask: taskStateStore.activeWorkflowTask
            ),
            persistentMemory: memoryStore.persistentMemoryContext(),
            attention: attentionContext
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
