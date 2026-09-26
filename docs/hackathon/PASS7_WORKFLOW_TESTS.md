# Pass 7 — Workflow intelligence (lightweight, manual test plan)

Uses **existing** `DexterActionHistoryStore` session history only. No new automation engine. **RUN** from Hub is off unless Mac sets `routineRunSupported` (currently false for detected patterns — catalog workflows are not auto-linked).

## When a suggestion appears

After **3+ verified actions of the same type** in recent session history (max 8 entries), once per app session, when a turn completes with Hub **Done.** (verified):

- Title: **I noticed you do this a lot.**
- Subtitle: **Want me to turn it into a routine?**
- **Yes** / **Not now**

## Trust

- **Yes** → Hub preview **I noticed something.** with trust copy; opens Dexter Home on Mac. Nothing runs automatically.
- **Not now** → dismisses for session.

## Negative

- No suggestion after 1–2 repeats.
- No silent routine creation.

## Mock (developer chrome)

Workflow suggestion is Mac-driven; use repeated real verified actions in one session to trigger, or extend mock later.

## Build

```bash
cd dexter-hub && npm run build
```

Mac: Xcode run (no terminal `xcodebuild`).
