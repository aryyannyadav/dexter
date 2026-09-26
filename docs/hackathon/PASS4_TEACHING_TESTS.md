# Pass 4 — Teaching experience (manual verification)

Run Dexter from **Xcode** with Hub connected. Teaching uses the **existing** `DexterTeachingEngine` and session store — no second model.

## Flow

1. Point at a target → invoke Dexter → say **“Teach me this.”**
2. Hub should show **“let's learn this.”** with the **real** target/window/app subtitle from pointer context (not a hardcoded demo string on live Mac).
3. During the lesson: **“here's what's happening.”** / **“your turn.”** / **“that's it.”** as the Mac teaching session phase changes.
4. If the model returns numbered steps, Hub shows a **short step rail** (Mac chat remains authoritative).
5. Optional **depth pills** (ELI5 → Expert) send `teachingStyle` to the Mac and affect the next teaching turn via `DexterHubTeachingStylePreferenceStore` + existing `DexterTeachingStyle`.

## Learn-by-doing

When the existing session enters **WAIT**, Hub shows **“your turn.”** After you complete a step on the Mac and say **done**, Hub may show **“that's it.”** — driven by `DexterTeachingSession` phase updates, not new computer control.

## Quiz mode

Not implemented (would need new backend). Skipped intentionally.

## Scenarios

| Scenario | What to verify |
|----------|----------------|
| PDF diagram | Topic subtitle from context; coaching copy |
| Browser UI | Step rail if response lists steps |
| VS Code concept | Depth pill changes style on next teach utterance |
| Unfamiliar app | Window/app subtitle when pointer target weak |

Console: `[DexterHub] teaching=COACHING` (and EXPLAINING / YOUR TURN / AFFIRMATION) during the lesson.

Mock Hub: **Teach demo** in the demo panel plays the updated `teachSequence`.
