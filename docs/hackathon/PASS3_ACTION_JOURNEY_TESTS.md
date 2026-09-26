# Pass 3 — Action journey (manual verification)

Run Dexter from **Xcode** with Hub connected. All Hub action UI is **presentation-only** — approve on the Mac.

## Expected journey

| Mac execution phase | Hub primary | Hub secondary |
|---------------------|-------------|---------------|
| Understanding / planning | thinking… | Sanitized `progressSummary` (actual planned action when available) |
| Proposal (wire) | I can do that. → Want me to? | `whatWillHappen` from confirmation |
| Waiting permission | Want me to do that? (uppercase) | Planned action + Allow / Not now |
| Executing | on it. | Actual action line |
| Verifying | checking… | Making sure it worked. |
| Completed + verified | Done. ✓ | Verified result text only |
| Completed + partial verify | I completed the action, but I couldn't verify the result. | Result hint — **no** success checkmark |
| Failed | That didn't work. | Real failure message; Try again only when Mac sends `retrySupported: true` |

## Mini timeline (when Mac sends `journeySteps`)

During thinking / permission / acting / verifying you should see a small row such as:

`UNDERSTAND ✓  PLAN ✓  ACT …  VERIFY`

## Scenarios to run

1. **Successful action** — Hub ends on Done. only if Mac verification is `verified`.
2. **Failed action** — Hub error, no success checkmark.
3. **Verification failure** — Hub error or idle (not success); no false Done.
4. **Permission denial** — Hub error or idle; **no** Try again if `retrySupported` is false.
5. **Cancelled action** — Hub returns to idle companion state.

Console: `[DexterHub] state=…` lines should match Mac `DexterRuntimeUIStateStore` / execution phase without duplicate identical fingerprints.
