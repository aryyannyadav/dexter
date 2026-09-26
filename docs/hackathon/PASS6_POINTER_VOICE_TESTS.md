# Pass 6 — Multimodal pointer + voice (manual test plan)

Audio/STT/TTS stay on the Mac. The Hub only reflects `DexterVoiceInteractionState` and runtime UI state (`voiceVisualOnly` on speaking — tablet does not play audio).

## Prerequisites

- Dexter running with Hub connected.
- Screen Recording + Accessibility + mic for PTT.
- Use **Point** (Dexter point shortcut) then hold **push-to-talk**.

## Tests

### 1. Point + “what is this?”

1. Point at a control, press PTT, say **“What is this?”**
2. Hub: **I'm listening...** with pointer target subtitle (not a generic app-only line).
3. After release: thinking beats / answer; Dexter uses pointer context (no need to name the control).

### 2. Point + teach / fix / next step

Repeat with **“Teach me this.”**, **“Fix this.”**, **“What should I do next?”** — same pointer context; no Hub-only command shortcuts.

### 3. Interruption

1. Let Dexter **speak** a response (TTS on Mac).
2. Press PTT again while speaking.
3. Hub should move **speaking → listening** immediately (Mac interruption unchanged).

### 4. Voice phases on Hub

| Mac phase | Hub visual |
|-----------|------------|
| Listening | listening character + **I'm listening...** |
| Thinking | thinking / journey as today |
| Speaking | **sharing the answer.** + `voiceVisualOnly` (listen on Mac) |
| Acting | **on it.** (runtime) |

### 5. STT failure

1. Release PTT with no audible speech (or empty transcript).
2. Hub: **I didn't catch that.** — not “Something went wrong.”

## Build

```bash
cd dexter-hub && npm run build
```

Mac: Xcode run (no terminal `xcodebuild`).
