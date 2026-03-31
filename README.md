<p align="center">
  <img src="beacon.svg" width="128" height="128" alt="Beakon">
</p>

<h1 align="center">Beakon</h1>

<p align="center">
  <strong>AI usage tracker & prompt vault for your macOS menu bar</strong>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#features">Features</a> •
  <a href="#providers">Providers</a> •
  <a href="#building-from-source">Build</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

Beakon is a native macOS menu bar app that tracks your AI usage limits across multiple providers and keeps your best prompts organized. See how much session/weekly capacity you have left at a glance — no dashboards to refresh.

## Features

### Usage Monitor

- **Multi-provider** — Claude Code, Cursor, Codex in one place
- **Live limits** — Session %, weekly %, extra usage with reset timers
- **OAuth auto-detect** — Reads existing CLI tokens, no manual setup
- **Token refresh** — Automatically refreshes expired tokens
- **Dashboard** — Overview + per-provider detail views with 7-day charts
- **Notifications** — Configurable alerts before hitting limits

### Prompt Vault

- **Local-first** — SwiftData-backed, all data stays on your machine
- **Search** — Full-text search (FTS5) across all prompts
- **Templates** — `{{variable}}` placeholders with fill UI
- **Organization** — Categories, tags, favorites, usage tracking
- **Portable** — JSON export/import

### Extras

- **Global hotkey** — `⌘+Shift+B` to open Beakon from anywhere
- **iCloud sync** — Optional CloudKit sync for prompt vault
- **No dependencies** — 100% Apple first-party frameworks

## Providers

Beakon reads OAuth tokens that your existing CLI tools have already stored locally. No browser login or API keys needed.

| Provider | Token Source | Data |
|----------|-------------|------|
| **Claude Code** | `~/.claude/.credentials.json` or Keychain | Session %, weekly %, extra usage, plan tier |
| **Cursor** | `~/Library/Application Support/Cursor/.../state.vscdb` | Total usage %, credits, auto/composer/API split |
| **Codex** | `~/.codex/auth.json` or `~/.config/codex/auth.json` | Session %, weekly %, credits balance |
| **Claude API** | Admin API key (manual) | Token usage, costs by model |

Copilot and ChatGPT providers are stubbed — waiting for OAuth/billing API access.

### How it works

1. You authenticate with the CLI tool as usual (`claude`, `cursor`, `codex`)
2. Beakon reads the locally stored OAuth token (one-time Keychain prompt on macOS)
3. Calls the provider's usage API to get live limit data
4. Refreshes expired tokens automatically

## Installation

### Homebrew

```bash
brew install --cask beakon
```

### Manual

Download the latest `.dmg` from the [Releases](https://github.com/ozers/beakon/releases) page.

### Building from Source

Requires Xcode 16+ and macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/ozers/beakon.git
cd beakon
open Beakon/Beakon.xcodeproj
# ⌘+R to build and run
```

No external dependencies.

## Project Structure

```
Beakon/
├── App/                  → Entry point, global state, hotkey, about
├── Features/
│   ├── MenuBar/          → Menu bar icon + popover (limit bars)
│   ├── Dashboard/        → Overview + per-provider detail views
│   ├── Usage/
│   │   ├── Providers/    → OAuth-based providers (Claude, Cursor, Codex, ...)
│   │   ├── Models/       → UsageSnapshot, ProviderLimits, AuthStatus
│   │   └── Services/     → Polling, history, orchestration
│   ├── Vault/            → Prompt library (SwiftData CRUD)
│   └── Settings/         → Preferences, Claude API key config
├── Core/
│   ├── Networking/       → HTTP client, Anthropic API
│   ├── Storage/          → Keychain, export/import
│   ├── Search/           → FTS5 full-text search
│   └── Notifications/    → Usage threshold alerts
└── Resources/            → Assets, entitlements
```

## Adding a New Provider

Implement the `UsageProvider` protocol:

```swift
final class MyProvider: UsageProvider {
    let id = "my-provider"
    let name = "My AI Service"
    let iconName = "brain.head.profile"

    var isConfigured: Bool {
        // Return true if OAuth token / credentials are available
    }

    func fetchUsage() async throws -> UsageSnapshot {
        // Read token, call usage API, return snapshot with limits
    }
}
```

Return `ProviderLimits` in the snapshot for automatic limit bar rendering:

```swift
UsageSnapshot(
    ...,
    limits: ProviderLimits(items: [
        .init(title: "Session", percent: 58, detail: "Resets in 1h 25m"),
        .init(title: "Weekly", percent: 22, detail: "Resets Fri 5:00 PM"),
    ]),
    planName: "Pro"
)
```

## Privacy & Security

- **No telemetry** — Zero analytics, zero tracking
- **Keychain** — Credentials read from existing CLI keychain entries (read-only)
- **Local data** — All vault data stored locally via SwiftData
- **Open source** — Full source code available for audit

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI (MenuBarExtra + WindowGroup) |
| Persistence | SwiftData (SQLite) |
| Charts | Swift Charts |
| Credentials | macOS Keychain (Security framework) |
| Networking | URLSession + async/await |
| Minimum | macOS 14.0 (Sonoma) |

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <sub>Beakon is not affiliated with Anthropic, Cursor, or OpenAI.</sub>
</p>
