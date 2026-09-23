# Dexter

Dexter is a macOS menu bar AI companion. It uses push-to-talk voice (or typed chat), optional screen context, and a blue on-screen cursor that can point at UI elements Claude references. The shipped app is named **Dexter**; API keys stay on a Cloudflare Worker proxy, not in the app binary.

## Documentation

| Document | Description |
|----------|-------------|
| [DEVELOPMENT.md](DEVELOPMENT.md) | Prerequisites, worker setup, Xcode build, permissions, testing |
| [ARCHITECTURE.md](ARCHITECTURE.md) | How Dexter is structured: voice, context, actions, worker |
| [AGENTS.md](AGENTS.md) | Detailed file map and conventions for coding agents |

## Quick start

1. Deploy the worker (`worker/`) and set secrets (see [DEVELOPMENT.md](DEVELOPMENT.md)).
2. Configure `DexterWorkerBaseURL` (and optional `DexterProxyClientKey`) in the app build.
3. Open `leanring-buddy.xcodeproj`, select the **leanring-buddy** scheme, sign, and run (⌘R).

## Repository layout

| Path | Purpose |
|------|---------|
| `leanring-buddy/` | macOS app (Swift/SwiftUI + AppKit) |
| `worker/` | Cloudflare Worker API proxy |
| `scripts/` | Release automation |

## Attribution

Dexter is derived from the open-source **Clicky** codebase (MIT). See [LICENSE](LICENSE) for copyright and license terms.
