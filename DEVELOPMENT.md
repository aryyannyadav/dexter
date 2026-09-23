# Developing Dexter

## Requirements

- macOS 14.2+ (ScreenCaptureKit)
- Xcode 15+
- Node.js 18+ (Cloudflare Worker)
- Accounts/keys for [Anthropic](https://console.anthropic.com), [AssemblyAI](https://www.assemblyai.com), and [ElevenLabs](https://elevenlabs.io) (stored on the worker only)

## Xcode project notes

- **Product name**: Dexter (`CFBundleDisplayName`)
- **Target / scheme**: `leanring-buddy` (legacy identifier — do not rename)
- **Module**: `leanring_buddy`

Prefer **⌘R in Xcode** over `xcodebuild` in Terminal so macOS privacy permissions (Screen Recording, Accessibility, Microphone) are not reset.

## Cloudflare Worker

```bash
cd worker
npm install

npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
# Recommended for production:
npx wrangler secret put DEXTER_PROXY_CLIENT_KEY

npx wrangler deploy
```

Set `ELEVENLABS_VOICE_ID` in `worker/wrangler.toml`. For local dev: `npx wrangler dev` and use `http://localhost:8787` as the worker base URL.

### App → worker configuration

Add to **Info.plist** or `Secrets.xcconfig` (see `leanring-buddy/Secrets.xcconfig.example`):

| Key | Purpose |
|-----|---------|
| `DexterWorkerBaseURL` | Worker origin (no trailing path) |
| `DexterProxyClientKey` | Must match worker `DEXTER_PROXY_CLIENT_KEY` when set |
| `PostHogProjectAPIKey` | Optional analytics |
| `PostHogHost` | Optional PostHog host |

All Claude, TTS, and AssemblyAI token traffic goes through `DexterWorkerProxyClient` (`/chat`, `/tts`, `/transcribe-token`).

**Do not** commit `OpenAIAPIKey` unless you intentionally use direct OpenAI transcription fallback.

## Permissions (first run)

Grant from the menu bar panel:

- **Accessibility** — global push-to-talk shortcut
- **Screen Recording** — screenshots via ScreenCaptureKit
- **Microphone** — voice input
- **Screen content** — shareable-content grant for capture

## Tests

In Xcode: **Product → Test** (⌘U), scheme `leanring-buddy`, target `leanring-buddyTests`.

## Release

See [scripts/README.md](scripts/README.md) for `release.sh` (DMG, notarization, Sparkle).
