# Pass 10 — Demo lock (manual test plan)

Presentation and operator tooling only. No pipeline / OpenClaw / verification changes.

## Start demo

```bash
# Mac: run Dexter from Xcode (Hub WebSocket on :8787)

# Hub (live — tablet/browser on same network as Mac)
cd dexter-hub && npm run dev -- --host 0.0.0.0

# Hub (mock fallback — no Mac required)
cd dexter-hub && VITE_DEXTER_USE_MOCK=true npm run dev -- --host 0.0.0.0
```

Open the printed URL on the demo device. Default **presentation / device mode** is on.

## Shortcuts

| Shortcut | When |
|----------|------|
| `Cmd/Ctrl+Shift+P` | Toggle presentation (device) mode |
| `Cmd/Ctrl+Shift+D` | Demo lock panel — **only when device mode is off** |

## Presentation mode

- Character, status, context rails, device chrome, connection indicator visible.
- No demo panel, no “Device mode off” chrome, no debug labels.

## Demo lock panel

1. `Cmd/Ctrl+Shift+P` → device mode off.
2. `Cmd/Ctrl+Shift+D` → **Dexter Demo Health** + sequences + **Reset demo**.

### Health

- Rows: DEXTER APP, WEBSOCKET, HUB, OPENCLAW, SCREEN, MICROPHONE, STT, TTS, OLLAMA (if enabled on Mac), VERIFICATION.
- `—` = unknown (not faked green). `×` = failed. `✓` = verified signal only.
- **Refresh** requests live snapshot from Mac (`requestDemoHealth`).

### Reset demo

- Hub returns to IDLE presentation; clears teach/memory/workflow/journey UI state.
- Does **not** delete Dexter memory or change Mac settings.
- Reconnects WebSocket if disconnected.

### Mock sequences (`VITE_DEXTER_USE_MOCK=true`)

- **Core demo** — `MOCK_CORE_DEMO`: IDLE → AWARE → LISTENING → THINKING → PERMISSION → ACTING → VERIFYING → SUCCESS.
- **Teach demo** / **Memory demo** — existing mock rails.
- **Manual states** — individual state buttons + simulate disconnect.

## Disaster recovery

- Hub disconnect → **Reconnect** control + disconnected copy.
- Dexter quit → WebSocket / DEXTER APP show failure until Mac app runs again.
- OpenClaw down → health row `×`; live errors from Dexter (no fake success).

## Build

```bash
cd dexter-hub && npm run build
```
