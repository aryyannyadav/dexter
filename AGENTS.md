# Dexter - Agent Instructions

<!-- This is the single source of truth for all AI coding agents. CLAUDE.md is a symlink to this file. -->
<!-- AGENTS.md spec: https://github.com/agentsmd/agents.md — supported by Claude Code, Cursor, Copilot, Gemini CLI, and others. -->

## Overview

macOS menu bar companion app (**Dexter**). Lives entirely in the macOS status bar (no dock icon, no main window). Clicking the menu bar icon opens a custom floating panel with companion voice controls. Uses push-to-talk (ctrl+option) to capture voice input, transcribes it via AssemblyAI streaming, and sends the transcript + a screenshot of the user's screen to Claude. Claude responds with text (streamed via SSE) and voice (ElevenLabs TTS). A blue cursor overlay can fly to and point at UI elements Claude references on any connected monitor.

All API keys live on a Cloudflare Worker proxy — nothing sensitive ships in the app.

## Architecture

- **App Type**: Menu bar-only (`LSUIElement=true`), no dock icon or main window
- **Framework**: SwiftUI (macOS native) with AppKit bridging for menu bar panel and cursor overlay
- **Pattern**: MVVM with `@StateObject` / `@Published` state management
- **AI Chat**: `DexterModelGateway` routes by capability (TEXT / VISION / REASONING / FAST / LOCAL) across local Ollama (`qwen3.5:9b` text, `qwen3.5:4b` vision, `think=false`), Claude via Worker proxy, and optional OpenAI; fallbacks on real failures only
- **Speech-to-Text**: AssemblyAI real-time streaming (`u3-rt-pro` model) via websocket, with OpenAI and Apple Speech as fallbacks
- **Text-to-Speech**: ElevenLabs (`eleven_flash_v2_5` model) via Cloudflare Worker proxy
- **Screen Capture**: ScreenCaptureKit (macOS 14.2+), multi-monitor support
- **Voice Input**: Push-to-talk via `AVAudioEngine` + pluggable transcription-provider layer. System-wide keyboard shortcut via listen-only CGEvent tap.
- **Element Pointing**: Claude embeds `[POINT:x,y:label:screenN]` tags in responses. The overlay parses these, maps coordinates to the correct monitor, and animates the blue cursor along a bezier arc to the target.
- **Concurrency**: `@MainActor` isolation, async/await throughout
- **Analytics**: PostHog via `DexterAnalytics.swift`

### API Proxy (Cloudflare Worker)

The app never calls external APIs directly. All requests go through a Cloudflare Worker (`worker/src/index.ts`) that holds the real API keys as secrets.

| Route | Upstream | Purpose |
|-------|----------|---------|
| `POST /chat` | `api.anthropic.com/v1/messages` | Claude vision + streaming chat |
| `POST /tts` | `api.elevenlabs.io/v1/text-to-speech/{voiceId}` | ElevenLabs TTS audio |
| `POST /transcribe-token` | `streaming.assemblyai.com/v3/token` | Fetches a short-lived (480s) AssemblyAI websocket token |

Worker secrets: `ANTHROPIC_API_KEY`, `ASSEMBLYAI_API_KEY`, `ELEVENLABS_API_KEY`, optional `DEXTER_PROXY_CLIENT_KEY` (requires matching `DexterProxyClientKey` in app Info.plist — not an upstream API key)
Worker vars: `ELEVENLABS_VOICE_ID`

App Info.plist (optional, no secrets in git): `DexterWorkerBaseURL`, `DexterProxyClientKey`, `PostHogProjectAPIKey`. See `leanring-buddy/Secrets.xcconfig.example`. Never commit `OpenAIAPIKey` or worker upstream keys.

### Key Architecture Decisions

**Menu Bar Panel Pattern**: The companion panel uses `NSStatusItem` for the menu bar icon and a custom borderless `NSPanel` for the floating control panel. This gives full control over appearance (dark, rounded corners, custom shadow) and avoids the standard macOS menu/popover chrome. The panel is non-activating so it doesn't steal focus. A global event monitor auto-dismisses it on outside clicks.

**Cursor Overlay**: A full-screen transparent `NSPanel` hosts the blue cursor companion. It's non-activating, joins all Spaces, and never steals focus. The cursor position, response text, waveform, and pointing animations all render in this overlay via SwiftUI through `NSHostingView`.

**Global Push-To-Talk Shortcut**: Background push-to-talk uses a listen-only `CGEvent` tap instead of an AppKit global monitor so modifier-based shortcuts like `ctrl + option` are detected more reliably while the app is running in the background.

**Shared URLSession for AssemblyAI**: A single long-lived `URLSession` is shared across all AssemblyAI streaming sessions (owned by the provider, not the session). Creating and invalidating a URLSession per session corrupts the OS connection pool and causes "Socket is not connected" errors after a few rapid reconnections.

**Transient Cursor Mode**: When "Show Dexter" is off, pressing the hotkey fades in the cursor overlay for the duration of the interaction (recording → response → TTS → optional pointing), then fades it out automatically after 1 second of inactivity.

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `leanring_buddyApp.swift` | ~89 | Menu bar app entry point. Uses `@NSApplicationDelegateAdaptor` with `CompanionAppDelegate` which creates `MenuBarPanelManager` and starts `CompanionManager`. No main window — the app lives entirely in the status bar. |
| `CompanionManager.swift` | ~1050 | Central UI state machine; wires **Dexter Voice** (PTT, STT, streamed text, optional TTS) via `DexterVoiceCoordinator`. Delegates model/context to `DexterOrchestrator`. |
| `Dexter/DexterVoiceCoordinator.swift` | ~125 | Listening / thinking / speaking lifecycle; PTT capture after interruption. |
| `Dexter/DexterCoreExecutionPipeline.swift` | ~40 | Shared PTT→STT→core runtime→TTS phase labels (`DexterUserInputChannel`). |
| `Dexter/DexterUserTurnExecutor.swift` | ~55 | Voice + text → `DexterOrchestrator.generateModelResponse` (no voice-only actions). |
| `Dexter/DexterUserTurnController.swift` | ~45 | Turn generation, cancel response/TTS/runtime action. |
| `Dexter/DexterPushToTalkSessionTracker.swift` | ~35 | Idempotent PTT release per session. |
| `Dexter/DexterSpokenResponseController.swift` | ~55 | TTS lifecycle (ElevenLabs when worker configured, local Mac fallback). |
| `Dexter/DexterTTSProvider.swift` | ~160 | `DexterSpokenResponseService`, local + ElevenLabs providers. |
| `Dexter/DexterVoiceSettingsStore.swift` | ~55 | Optional push-to-talk and spoken-response toggles (UserDefaults). |
| `Dexter/DexterVoiceSystemPrompt.swift` | ~25 | Concise spoken-response system prompt. |
| `DexterVoiceTextInputView.swift` | ~70 | Panel text input when voice is off or alongside PTT. |
| `Dexter/DexterOrchestrator.swift` | ~150 | Coordinates `ContextProvider`, `ModelProvider`, `MemoryStore`, `PermissionManager`, `AgentRuntime`, and `ActionVerifier`. |
| `Dexter/ModelProvider.swift` | ~95 | Model abstraction; `ClaudeModelProvider`, `OllamaModelProviderAdapter` + `VisionProvider`. |
| `Dexter/DexterModelGateway.swift` | ~150 | Capability-aware router over Ollama / Claude / OpenAI with honest fallback (no fabricated success). |
| `Dexter/DexterModelGatewayRouter.swift` | ~200 | Routes by complexity, vision, privacy, latency, and backend availability. |
| `Dexter/OllamaModelConfiguration.swift` | ~15 | Local models: text `qwen3.5:9b`, vision `qwen3.5:4b` (`think=false` in Ollama requests). |
| `Dexter/OpenAIModelProvider.swift` | ~75 | Optional OpenAI chat/vision `ModelProvider` when `OpenAIAPIKey` is configured. |
| `Dexter/VisionProvider.swift` | ~70 | Vision protocol, scopes (full/pointer/region), structured observations. |
| `Dexter/OllamaVisionProvider.swift` | ~80 | Local Ollama vision (`qwen3.5:4b`, think=false, stream=false). |
| `Dexter/FallbackVisionProvider.swift` | ~55 | Primary/fallback vision backends (information only, no actions). |
| `Dexter/DexterVisionRequestPreparer.swift` | ~55 | Scope-selected JPEG payloads from `DexterContext` (1280 max edge). |
| `Dexter/MemoryStore.swift` | ~280 | `MemoryStore` protocol, session history, structured memory engine facade. |
| `Dexter/PersistentMemoryStore.swift` | ~175 | On-disk `DexterStructuredMemoryRecord` store + v1 migration (`~/Library/Application Support/Dexter/`). |
| `Dexter/DexterMemoryModels.swift` | ~200 | Memory types (EPISODIC…COMMITMENT), structured record, legacy entry mapping. |
| `Dexter/DexterMemoryEngine.swift` | ~120 | Save/supersede/forget/update + recall summaries. |
| `Dexter/DexterMemoryRetrievalEngine.swift` | ~100 | Query → rank → stale/conflict filter for context injection. |
| `Dexter/DexterMemoryContentPolicy.swift` | ~55 | Rejects webpage instructions and unsafe memory payloads. |
| `Dexter/DexterMemoryInferenceTracker.swift` | ~55 | Session behavior counts → optional confirmation prompt (never silent inference). |
| `Dexter/DexterMemoryIntentProcessor.swift` | ~200 | remember/forget/update/recall intents; explicit-only persistence. |
| `Dexter/DexterPersonalContextGraphModels.swift` | ~150 | Graph entity/relationship kinds + authorized context input. |
| `Dexter/DexterPersonalContextGraphBuilder.swift` | ~220 | Builds in-memory graph from memory + authorized environment. |
| `Dexter/DexterIntegrationProvider.swift` | ~120 | `IntegrationProvider` protocol + registry; cross-app context composer. |
| `Dexter/DexterIntegrationProviders.swift` | ~280 | VS Code, terminal, browser, GitHub, documents, calendar, communication providers. |
| `Dexter/DexterPersonalContextIntegrations.swift` | ~70 | Legacy facades over integration providers. |
| `Dexter/DexterPersonalContextIntentRecognizer.swift` | ~60 | “where was I?”, “catch me up”, “what’s next?”, etc. |
| `Dexter/DexterPersonalContextQueryEngine.swift` | ~130 | Answers from graph only (no fabricated project state). |
| `Dexter/DexterPersonalContextGraph.swift` | ~45 | Facade + orchestrator short-circuit for personal context queries. |
| `Dexter/DexterTask.swift` | ~100 | `DexterTask`, `TaskStep`, `TaskState` for bounded assignment workflows. |
| `Dexter/DexterAccountabilityTask.swift` | ~120 | Structured user tasks (status, steps, commitment, verification). |
| `Dexter/DexterAccountabilityTaskStore.swift` | ~120 | On-disk accountability tasks (`accountability-tasks.json`). |
| `Dexter/DexterAccountabilityIntentRecognizer.swift` | ~90 | “remind me”, “what’s next?”, unfinished, continue work. |
| `Dexter/DexterAccountabilityQueryEngine.swift` | ~130 | Grounded answers from stored tasks/memory only. |
| `Dexter/DexterAccountabilityIntentProcessor.swift` | ~90 | Reminder + task declaration intents. |
| `Dexter/DexterAccountabilityReminderBridge.swift` | ~35 | COMMITMENT memory + expiration for scheduling hooks. |
| `Dexter/DexterAccountabilityContextPlanner.swift` | ~55 | Context packet + intent plan supplements. |
| `Dexter/DexterWorkspaceSnapshot.swift` | ~120 | Semantic workspace snapshot models (apps, windows, browser tab, project, task, files—no coordinates). |
| `Dexter/DexterWorkspaceSnapshotCapture.swift` | ~130 | Builds snapshots from authorized context + personal context graph. |
| `Dexter/DexterWorkspaceSnapshotStore.swift` | ~90 | On-disk workspace snapshots (`workspace-snapshots.json`). |
| `Dexter/DexterWorkspaceIntentRecognizer.swift` | ~40 | “save my workspace” / “restore my workspace” utterances. |
| `Dexter/DexterWorkspaceRestorePlanner.swift` | ~200 | Inspect current vs desired, plan semantic restore steps (open app, browser URL, memory). |
| `Dexter/DexterWorkspaceRestoreEngine.swift` | ~90 | Compare → plan → permission-gated execute → verify via action pipeline. |
| `Dexter/DexterProactiveEvent.swift` | ~120 | Proactive events, automation limits, pipeline phases. |
| `Dexter/DexterProactiveEventDetector.swift` | ~150 | Deadline, file, workflow, app, calendar detectors (authorized inputs only). |
| `Dexter/DexterProactivePolicyEngine.swift` | ~120 | detect→explain→suggest→ask; execute only if explicitly enabled. |
| `Dexter/DexterProactiveAutomationRegistry.swift` | ~75 | Per-event default limits (time/action/permission/app/stop). |
| `Dexter/DexterProactiveAutomationSettingsStore.swift` | ~45 | UserDefaults persistence for enabled automations. |
| `Dexter/DexterProactiveAgentBridge.swift` | ~55 | Proposes actions; execution via existing verified action pipeline. |
| `Dexter/DexterProactiveFoundationEngine.swift` | ~120 | Thin facade: proactive events → `DexterSkillAutomationRuntime` (no separate engine). |
| `Dexter/DexterAutomationRuntimeState.swift` | ~25 | RUNNING / STOPPING / STOPPED / FAILED / RECOVERING. |
| `Dexter/DexterTrustSafetyPolicy.swift` | ~75 | Permission levels, safety envelope, stop conditions, app scope. |
| `Dexter/DexterExecutionSafetyGuard.swift` | ~95 | Pre-execution gate (emergency stop, budgets, self-grant, injection). |
| `Dexter/DexterEmergencyStopController.swift` | ~55 | Global kill switch (shared). |
| `Dexter/DexterTrustRecoveryEngine.swift` | ~25 | Safe idle recovery after stop/failure. |
| `Dexter/DexterUserTrustControls.swift` | ~35 | Disable, revoke auto-approve, clear memory, revoke proactive automations. |
| `Dexter/DexterExternalContentAuthorityPolicy.swift` | ~45 | External content is DATA not AUTHORITY (prompt-injection defense). |
| `Dexter/DexterModelSelfGrantDefense.swift` | ~40 | Rejects model attempts to self-grant permissions/confirmations. |
| `Dexter/TaskPlanner.swift` | ~90 | Allowlisted workflow templates (assignment submission v1). |
| `Dexter/DexterTaskWorkflowRunner.swift` | ~350 | Multi-step turn processor; AgentRuntime only on Safari step. |
| `Dexter/DexterLearnedWorkflow.swift` | ~125 | Reusable workflow models, run session, runtime phases; recording placeholder (off). |
| `Dexter/DexterWorkflowCatalog.swift` | ~165 | Built-in workflows (e.g. prepare coding environment) with semantic steps only. |
| `Dexter/DexterWorkflowStepPlanner.swift` | ~120 | Maps workflow steps to `DexterAction` via fresh context; rejects coordinates. |
| `Dexter/DexterWorkflowRuntimeEngine.swift` | ~255 | TRIGGER→…→NEXT STEP runtime; reuses verified action pipeline. |
| `Dexter/DexterTaskStateStore.swift` | ~85 | `DexterWorkflowTaskStateStore` syncs assignment + learned workflow + memory task description. |
| `DexterMemoryManagementView.swift` | ~150 | Menu bar UI to view/remove session and persistent Dexter memory. |
| `Dexter/DexterContext.swift` | ~120 | Typed `DexterContext` and screen capture snapshots. |
| `Dexter/DexterContextModels.swift` | ~80 | Sub-structures (pointer, app, window, clipboard, task, etc.). |
| `Dexter/DexterContextAssembler.swift` | ~350 | Context Engine: relevance-aware collection → `DexterContextPacket` → legacy `DexterContext` (request-driven ScreenCaptureKit only). |
| `Dexter/DexterContextPacket.swift` | ~100 | `ContextPacket` sections, relevance levels, assembly diagnostics. |
| `Dexter/DexterContextCollectionPlanner.swift` | ~120 | Minimum sufficient context plan per request (OBJECT…LONG_TERM). |
| `Dexter/DexterContextEngineLog.swift` | ~30 | `[DEXTER][CONTEXT]` collected/skipped logging (no raw screen content). |
| `Dexter/DexterObservabilityRedaction.swift` | ~55 | Redacts tokens, secrets, long payloads before structured logs. |
| `Dexter/DexterObservabilityLog.swift` | ~75 | `[DEXTER][TASK|CONTEXT|INTENT|…|VOICE|PERF]` with per-task `task_id` prefix. |
| `Dexter/DexterPerformanceTiming.swift` | ~55 | Hotkey→context and sub-stage latency (`screen_capture`, `ocr`, `vision`, `intent`, `plan`, `tts`). |
| `Dexter/DexterConversationPackaging.swift` | ~55 | Recent messages + earlier-session summary + bounded API history. |
| `Dexter/DexterPointerAnalysisPolicy.swift` | ~45 | Skip OCR/vision when Accessibility is sufficient. |
| `Dexter/DexterTrivialQuestionClassifier.swift` | ~45 | Minimal context + no intent planner for short factual turns. |
| `Dexter/DexterTaskTrace.swift` | ~190 | Task trace phases, latency buckets, operational outcome categories. |
| `Dexter/DexterTurnTrace.swift` | ~40 | Voice-turn bridge: `beginTurn` / `finish` → `DexterTaskTraceRecorder`. |
| `Dexter/DexterContextPacketBuilder.swift` | ~130 | Tools/browser/project collectors + legacy context mapper. |
| `Dexter/DexterContextRelevancePlanner.swift` | ~120 | Chooses which context sections belong in each model request. |
| `Dexter/DexterStructuredModelRequestBuilder.swift` | ~180 | Builds structured USER REQUEST / POINTER / SCREEN / … prompts for `ModelProvider`. |
| `Dexter/DexterResponseMode.swift` | ~15 | ANSWER / EXPLAIN / TEACH / TROUBLESHOOT / GUIDE / ACT modes. |
| `Dexter/DexterIntentEngine.swift` | ~80 | Structured intent routing, complexity classification, clarification policy. |
| `Dexter/DexterIntentRouter.swift` | ~220 | Rule-based `DexterStructuredIntent` (intent + target + confidence). |
| `Dexter/DexterIntentPlanner.swift` | ~120 | COMPLEX intent plans (goal, steps, tools, permissions, budgets). |
| `Dexter/DexterIntent.swift` | ~90 | Intent kinds, targets, plan models. |
| `Dexter/DexterSkill.swift` | ~120 | Skill models (trigger, inputs, capabilities, workflow binding, verification, memory). |
| `Dexter/DexterSkillCatalog.swift` | ~280 | Seven internal skills (Coding, Research, BrowserResearch, FileOrganization, Study, Productivity, DevelopmentEnvironment). |
| `Dexter/DexterSkillResolver.swift` | ~75 | Trigger + intent alignment scoring. |
| `Dexter/DexterSkillAutomationRuntime.swift` | ~280 | **Single runtime** for skills, workflows, and proactive: Skill→Trigger→…→Memory; `plan` + `execute`. |
| `Dexter/DexterAutomationTrigger.swift` | ~70 | Manual, scheduled, event, and context trigger models (internal API). |
| `Dexter/DexterAutomationEnvelope.swift` | ~100 | Shared goal, time/action/permission limits, app scope, stop conditions. |
| `Dexter/DexterSkillEngine.swift` | ~55 | Resolves skill, merges intent plan; uses canonical runtime pipeline phases. |
| `Dexter/DexterSkillPlanMerger.swift` | ~55 | Merges skill requirements into `DexterIntentPlan`. |
| `Dexter/DexterSkillContextAdjuster.swift` | ~45 | Skill-driven context relevance tweaks. |
| `Dexter/DexterSkillPromptBuilder.swift` | ~50 | ACTIVE SKILL prompt section for model requests. |
| `Dexter/DexterSkillEngineLog.swift` | ~15 | `[DEXTER][SKILL]` resolution logging. |
| `Dexter/DexterTeachingIntentRecognizer.swift` | ~15 | Maps structured intents to legacy `DexterResponseMode`. |
| `Dexter/DexterTeachingMode.swift` | ~90 | Teaching modes, step phases, session model, context fingerprints (no screen storage). |
| `Dexter/DexterTeachingEngine.swift` | ~220 | Resolves teaching mode/style from `ContextPacket`; step WAIT/VERIFY gating. |
| `Dexter/DexterTeachingSessionStore.swift` | ~25 | Session-scoped lesson progress (metadata only). |
| `Dexter/DexterTeachingPacketPromptBuilder.swift` | ~45 | ContextPacket summaries for teaching prompts. |
| `Dexter/DexterTeachingModeInstructions.swift` | ~180 | Teaching-mode system prompt supplements + context plan adjustments. |
| `Dexter/DexterAttentionContext.swift` | ~150 | Pointer region + screenshot-space attention geometry. |
| `Dexter/DexterPointerIntelligence.swift` | ~80 | Pointer semantic target models and pipeline input types. |
| `Dexter/DexterPointerIntelligencePipeline.swift` | ~70 | mouse → display → window → app → region → AX → OCR → vision → semantic target. |
| `Dexter/DexterPointerSemanticTargetResolver.swift` | ~120 | Fuses AX, app metadata, OCR, and local vision with confidence. |
| `Dexter/DexterPointerRegionOCRAnalyzer.swift` | ~100 | Vision OCR on on-demand attention region only. |
| `Dexter/DexterPointerRegionVisionAnalyzer.swift` | ~100 | Local color/appearance hints at pointer (e.g. “why is this red?”). |
| `Dexter/DexterPointerScreenshotRegionCropper.swift` | ~35 | Crops ScreenCaptureKit snapshots to attention regions. |
| `Dexter/DexterPointerElementLocationCorroboration.swift` | ~40 | Corroborates pointer target when `ElementLocationDetector` agrees. |
| `Dexter/DexterPointerAccessibilityHintCollector.swift` | ~70 | Unverified AX hints at pointer (not UI identity). |
| `Dexter/DexterDevelopmentContextInspector.swift` | ~80 | DEBUG-only last-invocation context snapshot for the menu bar panel. |
| `CompanionDevelopmentContextInspectorView.swift` | ~60 | DEBUG SwiftUI inspector toggle and rows. |
| `Dexter/DexterEnvironmentContextCollector.swift` | ~120 | Active app/window/selection via Accessibility. |
| `Dexter/ContextProvider.swift` | ~25 | Legacy adapter over `DexterContextAssembler`. |
| `Dexter/PermissionManager.swift` | ~45 | macOS permission snapshot + request helpers. |
| `Dexter/AgentRuntime.swift` | ~210 | Agent execution boundary; `OpenClawAgentRuntimeAdapter` validates registered tools then executes via `DexterToolRegistryGateway` → OpenClaw Tool Gateway. |
| `Dexter/DexterTool.swift` | ~140 | Typed tool invocations mapped from `DexterAction`; registered tool names for registry validation. |
| `Dexter/DexterRegisteredTool.swift` | ~80 | Registered tool names, definitions, proposals, and model metadata. |
| `Dexter/DexterToolRegistryCatalog.swift` | ~180 | Canonical catalog (`screen.capture`, `application.launch`, `browser.*`, …) with risk, permissions, runtime, verification. |
| `Dexter/DexterToolRegistry.swift` | ~100 | Filters catalog by machine/runtime; builds AVAILABLE TOOLS prompt metadata. |
| `Dexter/DexterToolRegistryGateway.swift` | ~95 | Single gateway: list tools, reject unknown/unavailable proposals, execute via existing `DexterToolGateway`. |
| `Dexter/DexterRegisteredToolRouter.swift` | ~130 | Maps registered tool proposals to `DexterToolInvocation` for OpenClaw dispatch. |
| `Dexter/DexterToolGateway.swift` | ~60 | Tool Gateway protocol and structured unavailable/dispatch outcomes. |
| `Dexter/OpenClawDexterToolGatewayAdapter.swift` | ~150 | OpenClaw Tool Gateway: capability discovery + `computer.act` / `screen.snapshot` / `browser.proxy` / `system.run`. |
| `Dexter/DexterOpenClawCapabilityDiscovery.swift` | ~100 | Runtime capability matrix for connected OpenClaw nodes. |
| `Dexter/OpenClawDexterToolInvokePlan.swift` | ~120 | Maps `DexterToolInvocation` to OpenClaw node invoke plans. |
| `Dexter/DexterBrowserState.swift` | ~145 | Browser state snapshot (URL, title, page identity, text, selection, task) + runtime JSON parsing. |
| `Dexter/DexterBrowserIntelligencePlanner.swift` | ~140 | ACT-mode utterances → browser actions (`open` / `search` / `read` / `click` / `type` / `back` / `forward`) for OpenClaw `browser.proxy`. |
| `Dexter/DexterBrowserVerificationEngine.swift` | ~200 | Post-action browser verification; fails without URL/title/text proof (no navigation success on dispatch alone). |
| `Dexter/DexterApprovedFilePathPolicy.swift` | ~75 | Approved-folder path gate for file tools (Documents/Desktop/Downloads/Dexter support). |
| `Dexter/DexterLocalFileToolExecutor.swift` | ~280 | Local `file.*` search/read/create/write/move/rename/delete via registry gateway. |
| `Dexter/DexterFileVerificationEngine.swift` | ~200 | File action verification (exists/absent/content/move). |
| `Dexter/DexterTerminalCommandPolicy.swift` | ~120 | Approved command templates only; rejects raw model shell strings. |
| `Dexter/DexterTerminalOutputSanitizer.swift` | ~45 | Output truncation + secret redaction. |
| `Dexter/DexterLocalTerminalToolExecutor.swift` | ~130 | Policy-gated `Process` execution with timeout/cancel. |
| `Dexter/DexterTerminalVerificationEngine.swift` | ~95 | Terminal verify from sanitized captured output. |
| `Dexter/DexterRegisteredToolLocalExecution.swift` | ~25 | Routes file/terminal tools through registry without OpenClaw. |
| `Dexter/MacDexterAgentRuntimeAdapter.swift` | ~210 | `MacDexterAgentRuntimeAdapter` (NSWorkspace open VS Code/Safari, paste fix via clipboard + Cmd+V) and `CompositeDexterAgentRuntime`. |
| `Dexter/DexterRuntimeUIState.swift` | ~220 | Panel/overlay UI state from execution state machine + voice + orchestrator hints (never DONE during VERIFYING). |
| `Dexter/DexterDemonstrationPhase.swift` | ~20 | Legacy phase name aliases mapping to `DexterRuntimeUIState`. |
| `Dexter/DexterExecutionStateMachine.swift` | ~300 | Canonical execution phases; snapshot callbacks feed `DexterRuntimeUIStateStore`. |
| `Dexter/DexterFixTagParser.swift` | ~55 | Parses `[DEXTER_FIX:…]` from teach responses; `DexterDemonstrationSessionStore` holds pending fix for “fix it”. |
| `Dexter/DexterPointerControlWorkflow.swift` | ~70 | POINT → ASK → EXPLAIN → ACT → VERIFY at the pointer (what is this / enable it → click + AX verify). |
| `Dexter/DexterActionObservationPointerResolver.swift` | ~20 | Uses click coordinates for post-action observation at the intended target. |
| `Dexter/DexterUserFacingErrorMessage.swift` | ~90 | Maps network, model, TTS, permission, and runtime failures to safe user-facing copy. |
| `Dexter/DexterAgentRuntimeExecutionGuard.swift` | ~40 | Action execution timeout + cancellation hook into `AgentRuntime.cancelCurrentAction()`. |
| `Dexter/DexterTypedAction.swift` | ~150 | Typed actions (OpenApplication, Click, RunTask, …), risk, state, and factories. |
| `Dexter/DexterActionStore.swift` | ~55 | In-memory typed action registry with state updates. |
| `Dexter/DexterActionPermissionPolicy.swift` | ~110 | PermissionManager action evaluation and runtime allowlist. |
| `Dexter/DexterActionPermissionSettings.swift` | ~45 | LOW_RISK auto-approve preference (UserDefaults). |
| `Dexter/DexterActionConfirmationPolicy.swift` | ~100 | READ_ONLY / LOW / MODERATE / HIGH confirmation rules + WHAT/WHY/WHERE copy. |
| `DexterActionConfirmationView.swift` | ~90 | Menu bar confirmation UI (Cancel / Allow). |
| `Dexter/DexterActionExecutionPipeline.swift` | ~150 | PLAN → PERMISSION → EXECUTE → OBSERVE → VERIFY → REPORT with optional safe retry. |
| `Dexter/DexterActionPlanner.swift` | ~110 | Voice ACT planner; browser intelligence first, then app lifecycle / pointer / taught `[DEXTER_FIX:…]`. |
| `Dexter/ActionVerifier.swift` | ~70 | `ObservingActionVerifier` wraps `DexterActionVerificationEngine` (SUCCESS / FAILED / UNCERTAIN). |
| `Dexter/DexterActionObservation.swift` | ~105 | Post-execute snapshots via `MacDexterActionContextObserver` (includes `browserState` for verify). |
| `Dexter/DexterActionVerificationEngine.swift` | ~200 | Compares intended vs observed state; does not trust runtime success alone. |
| `Dexter/DexterActionRecoveryMetadata.swift` | ~220 | Semantic before/intended/after state, reversibility, rollback strategy per action. |
| `Dexter/DexterActionRecoveryLedger.swift` | ~55 | In-memory ledger of completed reversible actions for undo. |
| `Dexter/DexterActionRecoveryEngine.swift` | ~65 | “Undo last safe action” rollback planning + intent recognition. |
| `Dexter/DexterActionVerificationRecoveryPolicy.swift` | ~45 | Explicit verification-failure recovery (one low-risk navigation retry only). |
| `Dexter/DexterActionSafeRetryPolicy.swift` | ~25 | Low-risk action types eligible for explicit verification retry. |
| `MenuBarPanelManager.swift` | ~243 | NSStatusItem + custom NSPanel lifecycle. Creates the menu bar icon, manages the floating companion panel (show/hide/position), installs click-outside-to-dismiss monitor. |
| `CompanionPanelView.swift` | ~15 | Hosts `DexterCompanionPanelContent` for the menu bar panel. |
| `DexterCompanionPanelContent.swift` | ~320 | Panel: experiential onboarding card, voice/chat, actions; Advanced disclosure for model/memory. |
| `Dexter/DexterInteractiveOnboarding.swift` | ~150 | First-run flow: point → explain → safe action → verify → finale prompts. |
| `DexterUIComponents.swift` | ~320 | Dexter cards, voice indicators, chat, execution/verification UI. |
| `Dexter/DexterVisualIdentity.swift` | ~40 | Signal-cyan brand tokens on graphite (`DS` surfaces). |
| `Dexter/DexterPanelPresentation.swift` | ~90 | View-model labels for voice/action/task UI (testable). |
| `OverlayWindow.swift` | ~881 | Full-screen transparent overlay hosting the blue cursor, response text, waveform, and spinner. Handles cursor animation, element pointing with bezier arcs, multi-monitor coordinate mapping, and fade-out transitions. |
| `CompanionResponseOverlay.swift` | ~217 | SwiftUI view for the response text bubble and waveform displayed next to the cursor in the overlay. |
| `CompanionScreenCaptureUtility.swift` | ~132 | Multi-monitor screenshot capture using ScreenCaptureKit. Returns labeled image data for each connected display. |
| `BuddyDictationManager.swift` | ~866 | Push-to-talk voice pipeline. Handles microphone capture via `AVAudioEngine`, provider-aware permission checks, keyboard/button dictation sessions, transcript finalization, shortcut parsing, contextual keyterms, and live audio-level reporting for waveform feedback. |
| `BuddyTranscriptionProvider.swift` | ~100 | Protocol surface and provider factory for voice transcription backends. Resolves provider based on `VoiceTranscriptionProvider` in Info.plist — AssemblyAI, OpenAI, or Apple Speech. |
| `AssemblyAIStreamingTranscriptionProvider.swift` | ~478 | Streaming transcription provider. Fetches temp tokens from the Cloudflare Worker, opens an AssemblyAI v3 websocket, streams PCM16 audio, tracks turn-based transcripts, and delivers finalized text on key-up. Shares a single URLSession across all sessions. |
| `OpenAIAudioTranscriptionProvider.swift` | ~317 | Upload-based transcription provider. Buffers push-to-talk audio locally, uploads as WAV on release, returns finalized transcript. |
| `AppleSpeechTranscriptionProvider.swift` | ~147 | Local fallback transcription provider backed by Apple's Speech framework. |
| `BuddyAudioConversionSupport.swift` | ~108 | Audio conversion helpers. Converts live mic buffers to PCM16 mono audio and builds WAV payloads for upload-based providers. |
| `GlobalPushToTalkShortcutMonitor.swift` | ~132 | System-wide push-to-talk monitor. Owns the listen-only `CGEvent` tap and publishes press/release transitions. |
| `ClaudeAPI.swift` | ~291 | Claude vision API client with streaming (SSE) and non-streaming modes. TLS warmup optimization, image MIME detection, conversation history support. |
| `OpenAIAPI.swift` | ~142 | OpenAI GPT vision API client. |
| `ElevenLabsTTSClient.swift` | ~81 | ElevenLabs TTS client. Sends text to the Worker proxy, plays back audio via `AVAudioPlayer`. Exposes `isPlaying` for transient cursor scheduling. |
| `ElementLocationDetector.swift` | ~335 | Detects UI element locations in screenshots for cursor pointing. |
| `DesignSystem.swift` | ~880 | Design system tokens — colors, corner radii, shared styles. All UI references `DS.Colors`, `DS.CornerRadius`, etc. |
| `WindowPositionManager.swift` | ~262 | Window placement logic, Screen Recording permission flow, and accessibility permission helpers. |
| `AppBundleConfiguration.swift` | ~28 | Runtime configuration reader for keys stored in the app bundle Info.plist. |
| `DexterWorkerProxyClient.swift` | ~40 | Worker base URL + optional `X-Dexter-Proxy-Key` header for all proxy API calls. |
| `DexterAnalytics.swift` | ~120 | PostHog analytics (optional; no message content in events). |
| `DexterCursorVisibilityPreferences.swift` | ~25 | Cursor overlay visibility UserDefaults (migrates legacy `isClickyCursorEnabled`). |
| `worker/src/index.ts` | ~142 | Cloudflare Worker proxy. Three routes: `/chat` (Claude), `/tts` (ElevenLabs), `/transcribe-token` (AssemblyAI temp token). |

## Build & Run

```bash
# Open in Xcode
open leanring-buddy.xcodeproj

# Select the leanring-buddy scheme, set signing team, Cmd+R to build and run

# Known non-blocking warnings: Swift 6 concurrency warnings,
# deprecated onChange warning in OverlayWindow.swift. Do NOT attempt to fix these.
```

**Do NOT run `xcodebuild` from the terminal** — it invalidates TCC (Transparency, Consent, and Control) permissions and the app will need to re-request screen recording, accessibility, etc.

## Cloudflare Worker

```bash
cd worker
npm install

# Add secrets
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY

# Deploy
npx wrangler deploy

# Local dev (create worker/.dev.vars with your keys)
npx wrangler dev
```

## Code Style & Conventions

### Variable and Method Naming

IMPORTANT: Follow these naming rules strictly. Clarity is the top priority.

- Be as clear and specific with variable and method names as possible
- **Optimize for clarity over concision.** A developer with zero context on the codebase should immediately understand what a variable or method does just from reading its name
- Use longer names when it improves clarity. Do NOT use single-character variable names
- Example: use `originalQuestionLastAnsweredDate` instead of `originalAnswered`
- When passing props or arguments to functions, keep the same names as the original variable. Do not shorten or abbreviate parameter names. If you have `currentCardData`, pass it as `currentCardData`, not `card` or `cardData`

### Code Clarity

- **Clear is better than clever.** Do not write functionality in fewer lines if it makes the code harder to understand
- Write more lines of code if additional lines improve readability and comprehension
- Make things so clear that someone with zero context would completely understand the variable names, method names, what things do, and why they exist
- When a variable or method name alone cannot fully explain something, add a comment explaining what is happening and why

### Swift/SwiftUI Conventions

- Use SwiftUI for all UI unless a feature is only supported in AppKit (e.g., `NSPanel` for floating windows)
- All UI state updates must be on `@MainActor`
- Use async/await for all asynchronous operations
- Comments should explain "why" not just "what", especially for non-obvious AppKit bridging
- AppKit `NSPanel`/`NSWindow` bridged into SwiftUI via `NSHostingView`
- All buttons must show a pointer cursor on hover
- For any interactive element, explicitly think through its hover behavior (cursor, visual feedback, and whether hover should communicate clickability)

### Do NOT

- Do not add features, refactor code, or make "improvements" beyond what was asked
- Do not add docstrings, comments, or type annotations to code you did not change
- Do not try to fix the known non-blocking warnings (Swift 6 concurrency, deprecated onChange)
- Do not rename the project directory or scheme (the "leanring" typo is intentional/legacy)
- Do not run `xcodebuild` from the terminal — it invalidates TCC permissions

## Git Workflow

- Branch naming: `feature/description` or `fix/description`
- Commit messages: imperative mood, concise, explain the "why" not the "what"
- Do not force-push to main

## Self-Update Instructions

<!-- AI agents: follow these instructions to keep this file accurate. -->

When you make changes to this project that affect the information in this file, update this file to reflect those changes. Specifically:

1. **New files**: Add new source files to the "Key Files" table with their purpose and approximate line count
2. **Deleted files**: Remove entries for files that no longer exist
3. **Architecture changes**: Update the architecture section if you introduce new patterns, frameworks, or significant structural changes
4. **Build changes**: Update build commands if the build process changes
5. **New conventions**: If the user establishes a new coding convention during a session, add it to the appropriate conventions section
6. **Line count drift**: If a file's line count changes significantly (>50 lines), update the approximate count in the Key Files table

Do NOT update this file for minor edits, bug fixes, or changes that don't affect the documented architecture or conventions.
