# Dexter

Dexter is a macOS menu bar AI companion. It lives in the status bar (no dock icon), listens when you hold the push-to-talk shortcut, captures your screen on demand, and responds with voice and an on-screen cursor that can point at UI elements.

API keys are kept on a Cloudflare Worker proxy — they are not shipped in the app binary.

This project is derived from the open-source Clicky codebase (MIT). See [LICENSE](LICENSE) for copyright and license terms.

## Prerequisites

- macOS 14.2+ (ScreenCaptureKit)
- Xcode 15+
- Node.js 18+ (for the Cloudflare Worker)
- API keys for [Anthropic](https://console.anthropic.com), [AssemblyAI](https://www.assemblyai.com), and [ElevenLabs](https://elevenlabs.io)

## Cloudflare Worker

```bash
cd worker
npm install

npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
```

Set `ELEVENLABS_VOICE_ID` in `worker/wrangler.toml`, then deploy:

```bash
npx wrangler deploy
```

For local development, use `npx wrangler dev` and point the app at `http://localhost:8787`.

Update the worker base URL in:

- `leanring-buddy/CompanionManager.swift` (`workerBaseURL`)
- `leanring-buddy/AssemblyAIStreamingTranscriptionProvider.swift` (`tokenProxyURL`)

## Build and run

Open `leanring-buddy.xcodeproj` in Xcode, select the **leanring-buddy** scheme, configure signing, and run (⌘R).

The built app is named **Dexter** in Finder and the menu bar.

Prefer building from Xcode rather than `xcodebuild` in the terminal, so macOS privacy permissions (screen recording, accessibility, microphone) stay valid.

## Project layout

| Path | Purpose |
|------|---------|
| `leanring-buddy/` | macOS app source (Swift/SwiftUI) |
| `worker/` | Cloudflare Worker API proxy |
| `AGENTS.md` | Agent and contributor architecture notes |

## Permissions

Dexter needs:

- **Accessibility** — global push-to-talk shortcut
- **Screen Recording** — ScreenCaptureKit screenshots
- **Microphone** — voice input
- **Screen content** — one-time approval via ScreenCaptureKit shareable content

Grant these from the menu bar panel on first launch.
