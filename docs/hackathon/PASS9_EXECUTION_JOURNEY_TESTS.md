# Pass 9 — Execution journey visualization (manual test plan)

Presentation only — same Mac execution pipeline and verification rules.

## Journey stages (real phases)

`UNDERSTAND → PLAN → ASK → ACT → VERIFY` from `DexterHubJourneySupport` + `DexterExecutionPhase`.

## Idle

- No timeline visible.

## Active action

1. Trigger an action that needs approval (e.g. open an app).
2. Hub shows vertical journey; **ASK** active at permission.
3. After allow: **ACT** active — title **ACTING**, subtitle safe action detail (e.g. opening app name).
4. **VERIFY** active — title **CHECKING**.

## Success

- Verified completion only → **Done.** + checkmark.
- Timeline shows all ✓ then **fades out** (does not stay forever).

## Failure

- Failed verification → **VERIFY** marked ×, hint **could not verify**, title **That didn't work.**

## Negative

- No success before `verificationOutcome: verified`.
- No OpenClaw/tool names in copy.

## Build

```bash
cd dexter-hub && npm run build
```

Mac: Xcode run (no terminal `xcodebuild`).
