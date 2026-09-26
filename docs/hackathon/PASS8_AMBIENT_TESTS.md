# Pass 8 — Ambient companion (manual test plan)

No dashboard, no rotating quotes, no fake notifications.

## 1. Idle

- Default title: **hey, I'm here.** subtitle **your digital companion**
- Character: very subtle breath (`hub-shell--ambient-idle`), low glow when settled
- No 45s title rotation

## 2. Application awareness

- Switch apps on Mac while Dexter is idle
- Hub: **WATCHING** rail updates (e.g. **VS CODE**) — state stays **idle**, no “I see you're working” takeover

## 3. Time greeting (once per Hub session)

- First connect or first idle after connect may show **good morning.** / **hey.** / **still working?** / **you're still here?** once (`sessionStorage`)
- Further idle cycles stay **hey, I'm here.**

## 4. Focus mode

- **Hub mute** (companion menu) → **I'm here if you need me.** on idle; no workflow suggestion cards
- Mac: `ambientFocus` when no proactive automations are explicitly enabled in Dexter settings

## 5. Active help

- During thinking (with journey), acting, verifying: **I've got it.** — stronger character glow when shell is awake

## 6. Success → idle

- After verified **Done.**, Hub holds success ~5.2s before returning to idle (no instant flash)

## 7. Silence

- No motivational rotation, no extra ambient chatter

## Build

```bash
cd dexter-hub && npm run build
```

Mac: Xcode run (no terminal `xcodebuild`).
