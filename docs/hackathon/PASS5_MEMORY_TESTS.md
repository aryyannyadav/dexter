# Pass 5 — Memory + Personalization (manual test plan)

Hub receives **presentation-only** memory events from `DexterHubMemoryMomentReporter` over WebSocket (port 8787). No new memory backend; VIEW/FORGET call existing `MemoryStore` / Dexter Home.

## Prerequisites

- Dexter Mac app running (Hub bridge installed from `CompanionManager`).
- `dexter-hub` connected to Mac (`npm run dev` or device build).
- Optional: mock mode → Demo → **Memory demo**.

## 1. Explicit save

1. In Dexter Home or voice, say something explicit, e.g. **“Remember that Eventra uses MongoDB.”**
2. **Expect Hub:**
   - Title: **I'll remember that.**
   - Subtitle: short safe summary (e.g. **Eventra uses MongoDB.**)
   - Soft glow + memory spark; character slightly attentive (~4s), then idle.
   - **VIEW** / **FORGET** only when Mac resolved a record id (`memoryActionsSupported`).

**FORGET:** Hub clears moment; Mac removes entry via `removePersistentEntry`.

**VIEW:** Opens Dexter main window (memory management in Home).

## 2. Later recall (contextual)

1. After a fact is stored, ask a grounded question that should pull memory, e.g. **“What database does Eventra use?”**
2. **Expect Hub (only when retrieval matched a question-like turn):**
   - Title: **I remembered.**
   - Subtitle: safe snippet from stored content (not internal ids/types).
   - No VIEW/FORGET on contextual recall.

## 3. Explicit recall

1. **“What do you remember?”** (or similar list/recall phrase).
2. Hub recall moment with snippet from assistant reply.

## 4. Project context

1. Active Dexter profile with a named file workspace (e.g. **Eventra**).
2. Start a turn so workspace attaches.
3. **Expect Hub:** subtle rail **WORKING ON** / **Eventra** (persists across memory moment reset).

## 5. Preference reflection

1. Store an explicit preference containing **concise** / **brief** (e.g. **“I prefer concise answers.”**).
2. On a later question-like turn where that preference is retrieved, Hub may show:
   - **Keeping this concise, like you prefer.**
3. If no matching preference text, no fabricated “like you prefer” line.

## 6. Negative checks

- No brain/database icons; no unsolicited “I remember…” on every turn.
- Hub does not show VIEW/FORGET when `memoryActionsSupported` is false.

## Build verify

```bash
cd dexter-hub && npm run build
```

Mac: build/run in Xcode (do **not** use terminal `xcodebuild` — TCC).
