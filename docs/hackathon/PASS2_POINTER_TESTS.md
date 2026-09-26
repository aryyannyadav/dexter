# Pass 2 — Point → “this” experience (manual verification)

Run Dexter from **Xcode** (do not use terminal `xcodebuild` — TCC). Connect Hub to `ws://<mac-ip>:8787/hub`.

## What to verify

1. **Point invoke** (signature shortcut) → Hub: **idle → aware** (~220ms) with “I see what you're looking at.” and a **real target subtitle** (not app name only when semantic target exists).
2. **Mac overlay**: soft halo at pointer for **~12s** (no large label on screen).
3. **Speak** a deictic phrase → Hub: **listening → thinking** with “Got it.” showing the same target subtitle, then answer summary.
4. **Low confidence** (<0.45): Hub shows **“I think you're pointing at … Is that right?”** (informational — confirm on Mac, no Hub YES/NO execution).

## Resolution path log line

After each point invoke, Console should include:

```text
[DEXTER][VOICE] point_invoke hub target=… source=… confidence=…
```

`source` is the **strongest evidence weight** from the existing resolver (`accessibility`, `applicationMetadata`, `ocr`, `vision`, or `none`).

## Scenarios (fill in after you run)

| Scenario | Expected dominant `source` | Notes |
|----------|---------------------------|--------|
| VS Code squiggle / error line | Often `accessibility` or `ocr` | Point at diagnostic text |
| Browser button | Often `accessibility` | |
| Telegram UI control | Often `accessibility` or `applicationMetadata` | |
| PDF diagram region | Often `ocr` or `vision` | AX may be weak in Preview |
| Selected text | Context uses selection; target label from AX/OCR | |

Record the actual `source=` value from the log for each row — do not use mocked Hub targets for sign-off.
