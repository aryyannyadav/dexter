# Dexter architecture

Dexter is a menu bar-only macOS app (`LSUIElement`). It does not use a main window or Dock icon. User interaction flows through a status item panel, a full-screen cursor overlay, and push-to-talk (⌃⌥ by default).

## High-level flow

```text
Push-to-talk / typed text
    → DexterVoiceCoordinator (listen / think / speak)
    → DexterOrchestrator
        → DexterContextAssembler (pointer, AX, optional screenshots, memory)
        → ModelProvider (Claude via worker SSE)
        → Optional: DexterActionPlanner + execution pipeline
    → Overlay (cursor, response, pointing tags)
    → Optional ElevenLabs TTS via worker
```

## Major components

### UI shell

- `MenuBarPanelManager` — status item and floating panel
- `DexterCompanionPanelContent` — panel UI (voice, chat, actions, memory, settings)
- `CompanionManager` — coordinates voice, permissions, overlay, onboarding
- `OverlayWindow` — multi-monitor cursor overlay and `[POINT:…]` animations

### Dexter intelligence (`leanring-buddy/Dexter/`)

- **Context** — `DexterContextAssembler`, relevance planner, structured prompts, pointer/attention geometry
- **Conversation** — `DexterOrchestrator`, teaching modes, memory (`MemoryStore` + optional disk persistence)
- **Actions** — typed actions, permission policy, confirmation UI, `DexterActionExecutionPipeline` (plan → permission → execute → observe → verify → report)
- **Runtime** — `MacDexterAgentRuntimeAdapter` (allowlisted local actions) + optional `OpenClawAgentRuntimeAdapter` fallback
- **Workflows** — bounded tasks (`DexterTaskWorkflowRunner`), pointer control demo path (`DexterPointerControlWorkflow`)
- **Phases** — `DexterDemonstrationPhaseStore` for visible SEEING → DONE states during demos

### Voice stack

- `BuddyDictationManager` + pluggable transcription (AssemblyAI streaming default)
- `DexterVoiceCoordinator` — interaction state and streaming response text
- Worker-backed STT token and TTS; no upstream API keys in the app when proxy is configured

### API proxy (`worker/`)

| Route | Upstream |
|-------|----------|
| `POST /chat` | Anthropic Messages (streaming) |
| `POST /tts` | ElevenLabs |
| `POST /transcribe-token` | AssemblyAI short-lived websocket token |

Optional `DEXTER_PROXY_CLIENT_KEY` gates all routes.

## Security model (summary)

- Upstream API keys live in Worker secrets only.
- Actions are allowlisted; high-risk steps require explicit confirmation.
- Verification compares observed environment state to intent; runtime success alone is not trusted.
- Analytics (PostHog) records counts/metadata, not full transcripts, when enabled.

## Legacy naming

Internal types still use **Companion** and **Buddy** prefixes from the upstream foundation. The user-facing product name is **Dexter** everywhere in UI and documentation.

For a file-level map, see [AGENTS.md](AGENTS.md).
