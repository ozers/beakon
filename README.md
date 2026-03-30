<p align="center">
  <img src="assets/beakon-icon.png" width="128" height="128" alt="Beakon">
</p>

<h1 align="center">Beakon</h1>

<p align="center">
  <strong>AI usage tracker & prompt vault for your macOS menu bar</strong>
</p>

<p align="center">
  <a href="#installation">Installation</a> •
  <a href="#features">Features</a> •
  <a href="#usage">Usage</a> •
  <a href="#building-from-source">Build</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  <img src="https://img.shields.io/github/stars/ozersubasi/beakon?style=social" alt="Stars">
</p>

---

Beakon is a lightweight, native macOS menu bar app that combines **AI usage monitoring** with a **personal prompt & knowledge vault**. Track your Claude API costs and usage limits at a glance, and keep your best prompts organized in one place.

<!-- TODO: Add screenshot -->
<!-- ![Beakon Screenshot](assets/screenshot.png) -->

## Why Beakon?

There are several Claude usage trackers out there. Beakon is different because it's **two tools in one**:

1. **Usage Monitor** — See your Claude costs, token usage, and session limits right in the menu bar. No more refreshing dashboards.
2. **Prompt Vault** — Store, search, and organize your prompts, system instructions, and AI boilerplates. Stop losing good prompts in chat history.

All data stays on your machine. No telemetry, no cloud, no tracking.

## Features

### Menu Bar — Usage Monitor

- 📊 Real-time Claude API usage and cost tracking
- 🎨 Color-coded status (green/yellow/red) based on usage thresholds
- ⏱️ 5-hour session window tracking with reset timer
- 📈 Cost charts with 7-day and 30-day trends
- 🔔 Configurable notifications before hitting limits
- 🔑 Supports Admin API keys, session keys, and Claude Code OAuth

### Vault — Prompt Library

- 📝 Save and organize prompts with categories and tags
- 🔍 Full-text search across all your prompts
- 📋 One-click copy to clipboard
- ⭐ Favorites and usage tracking
- 📤 JSON export/import for portability
- ⌨️ Global keyboard shortcut (⌘+Shift+B)

### Coming Soon

- 🖥️ Cursor usage tracking
- 🤖 OpenAI / Copilot support
- 📦 Boilerplate template snippets
- 🔖 AI resource bookmarks
- ☁️ Optional iCloud sync

## Installation

### Homebrew (Recommended)

```bash
brew install --cask beakon
```

### Manual Download

Download the latest `.dmg` from the [Releases](https://github.com/ozersubasi/beakon/releases) page.

### Building from Source

Requires Xcode 16+ and macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/ozersubasi/beakon.git
cd beakon
open Beakon.xcodeproj
# Press ⌘+R to build and run
```

## Usage

### Setting Up Claude Tracking

#### Option A: Admin API Key (for API / Claude Code users)

1. Go to [Anthropic Console](https://console.anthropic.com/) → Settings → Admin API Keys
2. Create a new Admin key
3. Open Beakon Settings → Providers → Claude → paste your key

This gives you token usage and cost data via the official Usage & Cost API.

#### Option B: Session Key (for Claude.ai subscription users)

1. Open Beakon Settings → Providers → Claude
2. Click "Sign in to Claude.ai" (uses built-in browser)
3. Or manually paste your session key (`sk-ant-sid01-...`)

This gives you 5-hour session limits and weekly usage data.

#### Option C: Claude Code Auto-detect

If you use Claude Code, Beakon automatically detects credentials from `~/.claude/` — no configuration needed.

### Using the Vault

- **Open Vault**: Click "Open Vault" in the menu bar popover, or press `⌘+Shift+B`
- **Add a prompt**: Click `+` or press `⌘+N`
- **Search**: `⌘+F` or type in the search bar
- **Copy a prompt**: Click the copy icon or select and press `⌘+C`
- **Export**: File → Export (saves all data as JSON)
- **Import**: File → Import (merge or replace)

## Project Structure

```
Beakon/
├── App/                          # App entry point, global state
├── Features/
│   ├── MenuBar/                  # Menu bar icon, popover
│   ├── Usage/
│   │   ├── Providers/            # UsageProvider protocol + implementations
│   │   ├── Models/               # UsageSnapshot, CostReport, TokenUsage
│   │   ├── Services/             # Polling, history, orchestration
│   │   └── Views/                # Dashboard, charts, breakdowns
│   ├── Vault/
│   │   ├── Prompts/              # Prompt CRUD, list, editor
│   │   ├── Boilerplates/         # Template snippets (planned)
│   │   └── Bookmarks/           # Saved links (planned)
│   └── Settings/                 # Provider config, preferences
├── Core/
│   ├── Networking/               # HTTP client, Anthropic API
│   ├── Storage/                  # Keychain, export/import
│   ├── Search/                   # FTS5 full-text search
│   └── Notifications/           # Usage threshold alerts
└── Resources/                    # Assets, entitlements
```

## Adding a New Provider

Beakon uses a protocol-based provider system. To add a new AI service:

```swift
struct MyProvider: UsageProvider {
    let id = "my-provider"
    let name = "My AI Service"
    let iconName = "brain.head.profile"

    func fetchUsage() async throws -> UsageSnapshot {
        // Fetch and return usage data
    }

    func configure(with credentials: ProviderCredentials) {
        // Store credentials in Keychain
    }
}
```

See `ClaudeAPIProvider.swift` for a complete reference implementation.

## Privacy & Security

- **No telemetry**: Zero analytics, zero tracking, zero outbound calls except to configured API endpoints
- **Keychain storage**: API keys and session keys are stored in the macOS Keychain
- **Local data**: All vault data is stored locally in `~/Library/Application Support/Beakon/`
- **Open source**: Full source code available for audit

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6 |
| UI Framework | SwiftUI |
| Persistence | SwiftData (SQLite) |
| Charts | Swift Charts |
| Credentials | macOS Keychain |
| Networking | URLSession + async/await |
| Auto-update | Sparkle |
| Distribution | Homebrew Cask |

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/awesome-feature`)
3. Commit your changes (`git commit -m 'Add awesome feature'`)
4. Push to the branch (`git push origin feature/awesome-feature`)
5. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/ozersubasi/beakon.git
cd beakon
open Beakon.xcodeproj
```

No external dependencies — everything uses Apple's first-party frameworks.

## Roadmap

- [x] Project setup & architecture
- [ ] Menu bar + Claude API usage tracking
- [ ] Prompt library (CRUD, search, categories)
- [ ] Cost charts (Swift Charts)
- [ ] Notification system
- [ ] Claude.ai session tracking
- [ ] Claude Code local file parsing
- [ ] Cursor provider
- [ ] Boilerplate & bookmark modules
- [ ] iCloud sync
- [ ] Homebrew Cask distribution
- [ ] Sparkle auto-update

## License

MIT — see [LICENSE](LICENSE) for details.

## Acknowledgments

Built by [Özer Subaşı](https://ozersubasi.com). Inspired by the macOS Claude usage tracker community.

---

<p align="center">
  <sub>Beakon is not affiliated with Anthropic. Claude is a trademark of Anthropic PBC.</sub>
</p>
