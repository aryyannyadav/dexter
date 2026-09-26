# FINAL DEMO LOCK — stop building

**Product is frozen.** Remaining work: rehearsal, reliability, presentation, backups — not features.

Do **not** change: Dexter Mac architecture, OpenClaw, Ollama, capture, audio, memory backend, Hub design, dependencies.

Fix only bugs that **break the live demo**.

Full operator detail: [`DEMO_RUNBOOK.md`](./DEMO_RUNBOOK.md)  
Rehearsal log: [`DEMO_REHEARSAL_LOG.md`](./DEMO_REHEARSAL_LOG.md)

---

## Demo setup (stage)

| Step | Check |
|------|--------|
| Mac | Dexter running from **Xcode** (not terminal `xcodebuild`) |
| Hub server | `cd dexter-hub && npm run dev -- --host 0.0.0.0` |
| Tablet | Same Wi‑Fi; Hub URL `http://<MAC_IP>:5173`; **Add to Home Screen**; fullscreen |
| WebSocket | Hub shows **Connected** (not Connecting) — `ws://<MAC_IP>:8787/hub` |
| Presentation | **Device mode ON** (default) — no demo panel, no dev toggle |
| Physical | Tablet beside Mac, angled toward judges |
| OpenClaw | Settings → connected gateway + node (Demo 1) |
| Teach tab | Safari: `docs/hackathon/demo-teach.html` open in background |

Mac IP: `ipconfig getifaddr en0`

---

## Demo 1 — Signature (primary)

1. User works normally on Mac.  
2. User **points** at a UI target (e.g. Telegram in Dock).  
3. User **invokes** Dexter (push-to-talk).  
4. Hub **wakes** (aware / listening).  
5. Dexter uses pointer context on Mac.  
6. Hub: **“I see what you're looking at.”**  
7. User: **“What is this?”** → Dexter explains (Mac + Hub thinking / answer).  
8. User: **“Fix it.”** (or action utterance, e.g. open/fix).  
9. Dexter asks **permission** — Hub: **“Want me to fix it?”** / Allow · Not now.  
10. User **approves on Mac** (authoritative; Hub Allow is presentation-only).  
11. Hub acting: **ACTING** + safe subtitle (journey) or **“I've got it.”**  
12. OpenClaw executes on Mac.  
13. Hub verifying: **CHECKING** / “Making sure it worked.”  
14. Dexter verifies on Mac.  
15. Hub **only if verified**: **“Done.”** (+ checkmark when `verificationOutcome: verified`).

**Never** show **Done.** before Mac verification succeeds.

Rehearse **≥10 full runs** — log in [`DEMO_REHEARSAL_LOG.md`](./DEMO_REHEARSAL_LOG.md).

---

## Demo 2 — Teach

1. Frontmost: unfamiliar UI or Safari **`demo-teach.html`**.  
2. Point → invoke Dexter.  
3. Say: **“Teach me this.”**  
4. Dexter explains on Mac; Hub shows **teaching** rail / coaching copy (not Success unless a verified action completed).

---

## Demo 3 — Memory

**Save (once per day):**

> Remember that Eventra uses MongoDB.

Hub: **“I'll remember that.”**

**Recall (later):**

> What database does Eventra use?

Dexter answers on Mac; Hub: **“I remembered.”** / MongoDB subtitle.

Reset for dry runs: remove entry in Dexter memory UI (operator only) — does not wipe other memory.

---

## Demo 4 — Failure (controlled, if safe)

One intentional failure (e.g. deny permission, bad target, OpenClaw offline).

Hub must show: **“That didn't work.”** — **never** **“Done.”**

Optional: VERIFY × on journey + “could not verify” when verification fails.

---

## Reliability — what to record (10× Demo 1)

| Signal | Watch for |
|--------|-----------|
| Latency | PTT → Hub listening; approve → ACTING; → CHECKING; → Done |
| Failures | Step # from script |
| WebSocket | Disconnects / reconnect loops |
| Events | Duplicated Hub titles / flicker |
| Actions | Double execution on Mac |
| States | Wrong transition (Success without verify) |
| False success | **Done.** without verified outcome |
| Visual | Character wrong pose, scroll, clip |
| Touch | Allow / Reconnect on tablet |

Fix **only** demo-blocking issues; do not expand scope.

---

## Backups (real demo stays primary)

| Backup | Use |
|--------|-----|
| **1 — Mock Hub** | `VITE_DEXTER_USE_MOCK=true npm run dev` — UX only; labeled MOCK internally |
| **2 — Screen recording** | One clean Demo 1 (Mac + Hub); file path: _______________ |
| **3 — Screenshots** | Idle+Connected, permission, CHECKING, Done., optional Mac panel — folder: _______________ |

Operator recovery: `Cmd/Ctrl+Shift+P` off → `Cmd/Ctrl+Shift+D` → **Reset demo** + health **Refresh** (never on stage for judges).

---

## Build check (Hub only)

```bash
cd dexter-hub && npm run build
```

---

## Final rule

**Stop building after this document.** Ship rehearsal and stage presence, not code.
