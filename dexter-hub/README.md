# Dexter Hub

Tablet-first ambient companion display for **Dexter**. The Mac runs intelligence; the Hub is Dexter’s presence beside you.

This package is isolated under `dexter-hub/` and does not modify the Dexter macOS app.

## Quick start

```bash
cd dexter-hub
npm install
npm run dev
```

The dev server binds to **`0.0.0.0:5173`** so a tablet on the same Wi‑Fi can connect.

### Open on your tablet

1. On your Mac, find your LAN IP (System Settings → Network, or `ipconfig getifaddr en0`).
2. On the tablet, open `http://<MAC_LAN_IP>:5173`.
3. Add to Home Screen (optional) and enter **fullscreen** — the Hub opens in **device mode** by default (character-first, minimal chrome).
4. A short startup (~1.7s) shows Dexter, then your time-of-day greeting, then idle.

## Device mode & demo

| Action | How |
|--------|-----|
| **Device mode (default)** | Fullscreen tablet experience: subtle top bar, floating status, ambient brighten on activity. On by default; persists in `localStorage` (`dexter-hub-presentation`). |
| **Exit device mode** | `Cmd+Shift+P` / `Ctrl+Shift+P`, or set `localStorage` `dexter-hub-presentation` to `"false"` and reload — then use “Device mode off” (bottom-right). |
| **Demo controller** | `Cmd+Shift+D` / `Ctrl+Shift+D` — only when device mode is off. |
| **Hackathon sequence** | In demo controller → **Run hackathon sequence** |
| **Teach / memory mocks** | Demo controller → **Teach demo** / **Memory demo** |
| **Tap Dexter** | ASK / TEACH / HELP / ACT menu |
| **Long press Dexter** | Identity card |

Mock mode is opt-in (`VITE_DEXTER_USE_MOCK=true`) for offline UI demos. By default the Hub connects to **`ws://<same-host-as-page>:8787/hub`** (Dexter Mac bridge).

## Real Dexter Mac connection

1. Run **Dexter** on your Mac (bridge starts automatically on port **8787**).
2. Run the Hub: `npm run dev`
3. On the tablet, open `http://<MAC_LAN_IP>:5173` (or preview port).
4. The Hub connects to `ws://<MAC_LAN_IP>:8787/hub` automatically.

Tablet **Allow / Not now** buttons are **presentation-only** today — approve actions on the Mac as usual. Hub commands are logged and never bypass Dexter permissions.

## Dexter state machine

States: `idle`, `aware`, `listening`, `thinking`, `acting`, `verifying`, `success`, `permission`, `error`, `disconnected`.

Events arrive through `DexterBridge` (`src/services/dexterBridge.ts`):

```json
{ "type": "state", "state": "thinking", "title": "thinking...", "subtitle": "Understanding what you're looking at" }
```

```json
{ "type": "context", "application": "VS Code", "title": "I see what you're working on." }
```

## Future Mac integration

The Mac app ships `DexterHubEventBridge` (WebSocket on port **8787**), fed by `DexterRuntimeUIStateStore` — the same authoritative UI lifecycle as the menu bar / Home UI. SUCCESS is emitted only when execution reaches **verified completion**.

Optional overrides:

```bash
VITE_DEXTER_USE_MOCK=true npm run dev
VITE_DEXTER_WS_URL=ws://192.168.1.10:8787/hub npm run dev
```

## Build

```bash
npm run build
npm run preview
```

Preview also listens on `0.0.0.0` for tablet testing.

## Hackathon demo (DEMO LOCK)

Stage checklist, exact scripts, backups, and failure handling: **[docs/hackathon/DEMO_RUNBOOK.md](../docs/hackathon/DEMO_RUNBOOK.md)**.

Teach demo page (open in Safari): **[docs/hackathon/demo-teach.html](../docs/hackathon/demo-teach.html)**.

## Assets

Character PNGs are copied from the Dexter app asset catalog into `public/` (transparent, full-body — not circular avatars). Primary hero: `public/dexter-character.png`.

## Project layout

```
dexter-hub/
  public/
  src/
    components/
    screens/HubHome.tsx
    state/dexterState.ts
    services/
      dexterBridge.ts
      mockDexterBridge.ts
      websocketDexterBridge.ts
    styles/
    types/
```
