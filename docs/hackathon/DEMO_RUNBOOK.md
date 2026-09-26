# Dexter — Hackathon demo runbook (DEMO LOCK)

**Goal:** Repeatable, judge-safe demos. **Product frozen** — see [`FINAL_DEMO_LOCK.md`](./FINAL_DEMO_LOCK.md).

**Rehearsal log:** [`DEMO_REHEARSAL_LOG.md`](./DEMO_REHEARSAL_LOG.md)

---

## Known-good demo environment

### Hardware & network

| Item | Requirement |
|------|-------------|
| Mac | Dexter built from Xcode (same machine every demo) |
| Tablet | Same device; Hub added to Home Screen, **fullscreen** |
| Wi‑Fi | One network; Mac + tablet; **no guest/isolation** |
| Mac LAN IP | Note before each session: `ipconfig getifaddr en0` (or active interface) |
| Hub URL | `http://<MAC_IP>:5173` (dev) or preview port after `npm run build && npm run preview` |
| WebSocket | `ws://<MAC_IP>:8787/hub` (automatic when Hub hostname matches Mac) |
| Firewall | Allow incoming **8787** (Dexter) and **5173** / preview port (Hub) on the Mac |

### Mac applications (live demos)

| Demo | App | Window / target |
|------|-----|-----------------|
| **Demo 1 — Core** | **Telegram** (installed) | Dock icon or empty desktop; action: **open Telegram** |
| **Demo 1 — Context** | **VS Code** (optional beat) | Any open project window for “I see what you're working on” idle context |
| **Demo 2 — Teach** | **Safari** | Open `docs/hackathon/demo-teach.html` from this repo (drag file into Safari or `file://` URL) |
| **Demo 3 — Memory** | Dexter Home or menu bar | No special app; use exact phrases below |

### OpenClaw (Demo 1 action path)

1. Dexter **Settings → OpenClaw runtime**: gateway **connected**, preferred node **connected**.
2. **Computer control** permissions granted (Accessibility + Screen Recording as required).
3. Re-check immediately before Demo 1 if the Mac slept or VPN changed.

### macOS permissions (Dexter)

- [ ] Accessibility  
- [ ] Screen Recording  
- [ ] Microphone (if using voice)  
- [ ] Push-to-talk works once (`ctrl + option` hold test)

### Hub (tablet)

- [ ] Hub shows **Connected** (top) — not **Connecting** stuck  
- [ ] **Device mode on** (default) — presentation mode; tablet beside Mac  
- [ ] If something looks like a web app: reload; do **not** toggle device mode off for judges  

**Hidden operator keys (not for judges):**

- `Cmd/Ctrl+Shift+P` — toggle device mode (keep **on** for stage)  
- `Cmd/Ctrl+Shift+D` — demo panel (only when device mode off)  
- `localStorage` `dexter-hub-presentation` = `"false"` — disables device mode (avoid on stage)

### Exact Dexter state expectations (Hub)

| Phase | Hub character | Floating status (examples) |
|-------|---------------|----------------------------|
| Idle | Idle | “hey, I'm here.” |
| Pointer / context | Speaking / aware | “I see what you're looking at.” |
| Listen | Listening | “I'm listening...” |
| Think | Thinking | “thinking...” |
| Permission | Listening | “Want me to do that?” + Allow / Not now |
| Act / verify | Working | **ACTING** / **CHECKING** (journey) or “I've got it.” / “Making sure it worked.” |
| **Success** | Success | **“Done.”** only when Mac sends `verificationOutcome: verified` |
| Failure | Error | **“That didn't work.”** — **never** Success / **Done.** |

Hub SUCCESS is gated on Mac: execution phase **completed** **and** verification **verified** or **partiallyVerified**. Failed verification maps to **error** or **idle**, not Success.

---

## Pre-flight (5 minutes)

1. Reboot not required; **quit and relaunch Dexter** from Xcode if permissions or OpenClaw look stale.  
2. Start Hub: `cd dexter-hub && npm run dev` (or preview build for stability).  
3. Open Hub on tablet; confirm CONNECTED.  
4. OpenClaw status green.  
5. Open Safari with **demo-teach.html** in a tab (background).  
6. Close extra Mac windows; quit apps not needed for the script.  

---

## Demo 1 — Core Dexter (repeat ≥10 times before stage)

**Script**

1. Dexter running; Hub connected; tablet fullscreen device mode.  
2. Focus Mac desktop (or VS Code briefly for context, then desktop).  
3. **Point** at **Telegram** in the Dock (or a known Telegram window target).  
4. **Invoke Dexter** (push-to-talk): e.g. “Open Telegram.”  
5. Confirm Mac captures context; Dexter explains / proposes opening Telegram.  
6. **Permission** on Mac (and Hub shows permission + Allow / Not now).  
7. **Approve** on Mac (Hub Allow is presentation-only; Mac approval is authoritative).  
8. OpenClaw / runtime executes open.  
9. Verification runs on Mac.  
10. Hub shows **SUCCESS** (“Done.”) only if verification succeeded.

**Log failures** (copy template):

| Run # | Failed step | Symptom | Mitigation |
|-------|-------------|---------|------------|
| 1 | | | |

**Common mitigations**

- Hub disconnected → same Wi‑Fi; relaunch Dexter; reload Hub.  
- OpenClaw disconnected → Settings; restart gateway/node; retry Demo 1 once.  
- Permission denied → approve on Mac; do not advance script.  
- Action failed / verify failed → Hub must **not** show Success; explain on Mac, retry.  
- Screen capture unavailable → grant Screen Recording; retry.  
- Vision timeout → simplify target (Dock icon); retry with shorter utterance.  

---

## Demo 2 — Teach

1. Safari frontmost with **`docs/hackathon/demo-teach.html`**.  
2. Point at **MongoDB** box or the API → DB arrow.  
3. Say: **“Teach me this.”**  
4. Verify: pointer context, screen context, spoken/text response on Mac, Hub **thinking** → answer beat / aware (not Success unless a verified **action** completed).  

---

## Demo 3 — Memory

Use **exact** wording (test once before stage):

**Save (once per demo day):**

> Remember that Eventra uses MongoDB.

**Later recall:**

> What database does Eventra use?

Verify: Mac answer mentions MongoDB; Hub **memory** moment (“I remembered.” / subtitle with MongoDB), then returns to idle.

To reset memory for a dry run: Dexter memory UI / remove that entry (operator only).

---

## Failure handling rehearsal

Run once each before stage (operator view):

| Scenario | How to simulate | Expected UI |
|----------|-----------------|-------------|
| Hub disconnected | Stop Dexter or wrong Wi‑Fi | Hub: disconnected / reconnect |
| OpenClaw disconnected | Stop gateway | Mac honest error; Hub **error**, not Success |
| Action failure | Deny permission or break target | **error** or idle |
| Permission denied | Not now | Returns to aware / idle |
| Screen capture off | Revoke (dev only) | Mac prompts; no fake Success |
| Vision timeout | Obscure target | Explain failure; no Success |

---

## Performance sanity check

During a full Demo 1 run, watch for:

- UI freezes on Mac or tablet  
- Duplicate Hub state flicker (Mac bridge dedupes; Hub ignores identical consecutive states)  
- Double action execution (only one Mac approval)  
- Double TTS (single spoken response)  
- Runaway character animation loops  
- Console errors on Hub (Safari Web Inspector) or `[DEXTER]` logs on Mac  

---

## Backup plans

### Backup A — Fully local deterministic Hub (no Mac WebSocket)

On a laptop or tablet browser:

```bash
cd dexter-hub
VITE_DEXTER_USE_MOCK=true npm run dev
```

Device mode on → judge-facing UI only; operator with device mode off: `Cmd/Ctrl+Shift+D` → **Run core demo** / **Teach demo** / **Memory demo** (mock only).

Does **not** prove OpenClaw; proves Hub UX only.

### Backup B — Recorded video

Record one clean **Demo 1** take (Mac + Hub in frame or cut): point → ask → permission → approve → verify → Hub Success.

Store file path here before stage: `___________________________`

### Backup C — Screenshots

Capture and keep offline copies:

1. Hub idle + CONNECTED  
2. Hub permission  
3. Hub verifying  
4. Hub **Done.** (Success)  
5. Mac permission / completion (optional second device photo)  

Store folder: `___________________________`

---

## Demo lock rules

- Do not upgrade npm packages or change architecture during demo week.  
- Do not enable experimental flags for judges.  
- If it is not required for the three demos, **do not touch it**.  

---

## Quick reference — operator commands

```bash
# Hub (stage Mac)
cd dexter-hub && npm run dev

# Hub local backup
cd dexter-hub && VITE_DEXTER_USE_MOCK=true npm run dev

# Mac IP
ipconfig getifaddr en0
```
