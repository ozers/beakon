# CLAUDE.md — Project Instructions for Beakon

## What is this project?

Beakon is a native macOS menu bar app (Swift 6 / SwiftUI) that combines AI usage monitoring with a personal prompt vault. It tracks Claude API costs and usage limits, and provides a local-first prompt library.

## Tech Stack

- **Language**: Swift 6 with strict concurrency
- **UI**: SwiftUI (MenuBarExtra + WindowGroup)
- **Persistence**: SwiftData (SQLite)
- **Charts**: Swift Charts
- **Credentials**: macOS Keychain (Security framework)
- **Networking**: URLSession + async/await
- **Minimum**: macOS 14.0 (Sonoma)
- **No external dependencies** — all Apple first-party

## Project Structure

```
Beakon/
├── App/           → Entry point, global state, constants
├── Features/
│   ├── MenuBar/   → Menu bar icon + popover views
│   ├── Usage/     → Provider protocol + Claude implementations + views
│   ├── Vault/     → Prompt library (SwiftData CRUD)
│   └── Settings/  → Provider config, preferences
├── Core/
│   ├── Networking/ → APIClient, AnthropicAPI
│   ├── Storage/    → KeychainService, ExportImportService
│   ├── Search/     → FTS5 search wrapper
│   └── Notifications/ → Usage threshold alerts
└── Resources/      → Assets, entitlements
```

## Key Patterns

### UsageProvider Protocol
Every AI service implements `UsageProvider`. When adding new code for a provider:
```swift
protocol UsageProvider {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    func fetchUsage() async throws -> UsageSnapshot
    func configure(with credentials: ProviderCredentials)
}
```

### SwiftData Models
All persistent entities use `@Model`. The main ones:
- `Prompt` — title, content, category, tags, notes, isFavorite, usageCount
- `UsageHistory` — historical snapshots for charts
- `ProviderConfig` — per-provider settings

### State Management
Use `@Observable` macro (not `@ObservableObject`). For global state, use `AppState` class injected via `.environment()`.

### Concurrency
Use `async/await` throughout. Network calls and Keychain access are async. Use `@MainActor` for view models that update UI.

## Anthropic API Endpoints

### Usage Report
```
GET /v1/organizations/usage_report/messages
Headers: x-api-key: $ADMIN_KEY, anthropic-version: 2023-06-01
Params: starting_at, ending_at, bucket_width (1m|1h|1d)
Optional: group_by (model, workspace_id, api_key, service_tier)
```

### Cost Report
```
GET /v1/organizations/cost_report
Headers: x-api-key: $ADMIN_KEY, anthropic-version: 2023-06-01
Params: starting_at, ending_at
Optional: group_by[] (workspace_id, description)
Returns: costs in USD cents as decimal strings
```

### Auth Types
- Admin API key: `sk-ant-api03-*` → for usage/cost endpoints
- Session key: `sk-ant-sid01-*` → for claude.ai subscription usage
- OAuth token: `sk-ant-oat01-*` → for Claude Code CLI

## Coding Guidelines

- No force unwraps (`!`) — use `guard let` or `if let`
- No external dependencies — only Apple frameworks
- Keep views small (< 100 lines), extract subviews
- Use SF Symbols for icons
- Support dark mode (all custom colors via asset catalog)
- Use `LocalizedStringKey` for user-facing strings (future i18n)
- Keychain operations go through `KeychainService` — never raw Security API
- All API keys go to Keychain, never UserDefaults or plaintext

## Build & Run

```bash
open Beakon.xcodeproj
# ⌘+R to build and run
# ⌘+U to run tests
```

## Important Files to Read First

1. `docs/PRD.md` — Full product spec with data models, API details, roadmap
2. `README.md` — User-facing documentation
3. `App/BeakonApp.swift` — Entry point, understand MenuBarExtra + WindowGroup setup
4. `Features/Usage/Providers/UsageProvider.swift` — Core protocol
