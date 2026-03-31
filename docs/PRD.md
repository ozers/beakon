# Beakon — Product Requirements Document

> macOS menu bar app: AI usage tracking + personal AI knowledge base
> Open source · Swift/SwiftUI · Privacy-first

---

## 1. Problem Statement

Developers using AI coding assistants (Claude, Cursor, Copilot) face two recurring problems:

1. **Usage blindness**: No unified view of how much they're consuming across services. Rate limits hit unexpectedly, costs accumulate silently, and there's no easy way to see consumption trends without opening multiple dashboards.

2. **Prompt & knowledge fragmentation**: Useful prompts, system instructions, boilerplate templates, and AI-related bookmarks are scattered across notes apps, browser bookmarks, and chat histories. There's no dedicated, searchable, local-first tool to organize this knowledge.

Existing solutions (Claude Usage Tracker, ClaudeBar, SessionWatcher) address only the first problem — and only for a single service. None combine monitoring with a personal AI knowledge base.

---

## 2. Product Vision

**Beakon** is a lightweight, native macOS menu bar app that gives developers a unified cockpit for their AI tool usage and a personal vault for AI-related knowledge — prompts, boilerplates, and references.

### Core Principles

- **Local-first**: All data stays on your machine. No telemetry, no analytics, no cloud dependency.
- **Native performance**: Swift/SwiftUI, sub-10MB footprint, minimal CPU/memory.
- **Open source**: MIT licensed, community-driven.
- **Modular**: Each AI service is a pluggable provider. Start with Claude, add others.

---

## 3. Target Users

- **Primary**: Developers actively using Claude (API or subscription) for coding, writing, and research
- **Secondary**: Power users who want to organize their prompt engineering workflow
- **Tertiary**: Teams wanting visibility into AI API spend

---

## 4. Feature Specification

### 4.1 Module: Usage Monitor (Menu Bar)

The always-visible component. Lives in the macOS menu bar, shows a glanceable usage indicator.

#### 4.1.1 Menu Bar Icon & Display

| Element | Description |
|---------|-------------|
| Icon | Minimal beacon/signal icon (SF Symbol or custom) |
| Text | Configurable: daily cost (`$2.34`), session % (`67%`), or both |
| Color | Green (< 50%), Yellow (50-80%), Red (> 80%) — based on session limit |

#### 4.1.2 Popover View (Click menu bar icon)

- **Session Usage**: 5-hour rolling window progress bar with reset timer
- **Weekly Usage**: 7-day limit progress bar
- **Daily Cost**: Today's API spend in USD (from Cost API)
- **Model Breakdown**: Per-model token consumption (Opus, Sonnet, Haiku)
- **Cost Chart**: 7-day / 30-day cost trend (Swift Charts)
- **Quick Actions**: Refresh, Open Settings, Open Vault

#### 4.1.3 Data Sources — Claude

**A. Anthropic Admin API (for API/Claude Code users)**

Endpoint: `GET /v1/organizations/usage_report/messages`
- Requires: Admin API key (`sk-ant-api03-*`)
- Data: Token counts by model, workspace, service tier
- Bucket widths: 1 minute, 1 hour, 1 day
- Polling: Every 5 minutes (configurable)

Endpoint: `GET /v1/organizations/cost_report`
- Data: Cost in USD (cents), grouped by workspace/description
- Parsed fields: model, inference_geo

**B. Claude.ai Session API (for subscription users)**

- Requires: Session key (`sk-ant-sid01-*`) or OAuth token (`sk-ant-oat01-*`)
- Data: 5-hour session usage, weekly usage, model-specific limits
- Auth methods:
  - Built-in WKWebView login (recommended)
  - Manual session key paste
  - Claude Code OAuth auto-detection (`~/.claude/` directory)

**C. Claude Code Local Files**

- Path: `~/.claude/projects/`
- Data: Local usage logs, JSONL format
- Parse: Token counts, model used, timestamps

#### 4.1.4 Notifications

| Trigger | Default | Configurable |
|---------|---------|-------------|
| Session usage > 75% | ✅ | Threshold % |
| Session usage > 90% | ✅ | Threshold % |
| Daily cost > budget | ❌ | Budget amount ($) |
| Session reset | ❌ | On/Off |

#### 4.1.5 Future Providers (Post-MVP)

| Provider | Data Source | Priority |
|----------|-----------|----------|
| Cursor | Local files (`~/.cursor/`) + API | P1 |
| OpenAI | API (`/v1/usage`) | P2 |
| GitHub Copilot | API | P3 |

Each provider implements a `UsageProvider` protocol:

```swift
protocol UsageProvider {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    func fetchUsage() async throws -> UsageSnapshot
    func configure(with credentials: ProviderCredentials)
}
```

---

### 4.2 Module: Vault (Main Window)

The knowledge base component. Opens as a standard macOS window (⌘+Shift+B or click "Open Vault" from popover).

#### 4.2.1 Prompt Library

The core collection feature. Store, organize, search, and copy prompts.

**Data Model: Prompt**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | UUID | ✅ | Auto-generated |
| title | String | ✅ | Short descriptive name |
| content | String | ✅ | The actual prompt text |
| category | String | ❌ | e.g., "System Prompt", "Code Review", "Writing" |
| tags | [String] | ❌ | Freeform tags for filtering |
| notes | String | ❌ | Personal notes about usage/context |
| isFavorite | Bool | ❌ | Pin to top |
| usageCount | Int | ❌ | Auto-increment on copy |
| createdAt | Date | ✅ | Auto-set |
| updatedAt | Date | ✅ | Auto-set |

**UI: Prompt List View**

- Left sidebar: Category filter + tag cloud
- Main area: Prompt cards in a list/grid
- Search bar: Full-text search (FTS5) across title, content, tags, notes
- Actions per prompt: Copy to clipboard, Edit, Duplicate, Delete
- Sort: Recent, Most Used, Alphabetical, Favorites First

**UI: Prompt Editor**

- Title field
- Content: Multi-line text editor with monospace font, syntax highlighting for common patterns ({{variable}}, XML tags)
- Category: Dropdown with auto-complete (creates new on type)
- Tags: Token input field
- Notes: Optional text area
- Preview: Rendered markdown preview toggle

#### 4.2.2 Boilerplate Snippets (Post-MVP)

Reusable template fragments — persona definitions, output format instructions, chain-of-thought skeletons.

**Data Model: Boilerplate**

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Auto-generated |
| title | String | e.g., "Senior Backend Engineer Persona" |
| content | String | Template text with `{{placeholders}}` |
| category | String | e.g., "Personas", "Output Formats", "CoT Templates" |
| variables | [String] | Extracted from `{{...}}` patterns |
| tags | [String] | Freeform |

#### 4.2.3 Bookmarks (Post-MVP)

Save links to useful AI resources — articles, tools, repos.

**Data Model: Bookmark**

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Auto-generated |
| title | String | Page title (auto-fetched or manual) |
| url | String | URL |
| description | String | Personal note |
| tags | [String] | Freeform |
| category | String | e.g., "Prompt Engineering", "Tools", "Research" |

#### 4.2.4 Cross-Module Features

- **Global Search**: Search across prompts, boilerplates, and bookmarks
- **JSON Export/Import**: Full data portability
  - Export: Single JSON file with all data, versioned schema
  - Import: Merge or replace modes
- **Keyboard Shortcuts**: ⌘+N (new), ⌘+F (search), ⌘+C (copy selected prompt)
- **Quick Access**: Global hotkey (e.g., ⌘+Shift+B) opens Vault window

---

## 5. Technical Architecture

### 5.1 Project Structure

```
Beakon/
├── Beakon.xcodeproj
├── Beakon/
│   ├── App/
│   │   ├── BeakonApp.swift              # @main, MenuBarExtra + WindowGroup
│   │   ├── AppState.swift               # Global state, settings
│   │   └── Constants.swift              # API URLs, defaults
│   ├── Features/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift        # Menu bar popover content
│   │   │   ├── MenuBarIconRenderer.swift # Dynamic icon drawing
│   │   │   └── UsageSummaryView.swift   # Compact usage display
│   │   ├── Usage/
│   │   │   ├── Providers/
│   │   │   │   ├── UsageProvider.swift       # Protocol
│   │   │   │   ├── ClaudeAPIProvider.swift   # Admin API
│   │   │   │   ├── ClaudeSessionProvider.swift # Session key
│   │   │   │   └── ClaudeCodeProvider.swift  # Local files
│   │   │   ├── Models/
│   │   │   │   ├── UsageSnapshot.swift       # Unified usage data
│   │   │   │   ├── CostReport.swift          # Cost breakdown
│   │   │   │   └── TokenUsage.swift          # Token counts
│   │   │   ├── Services/
│   │   │   │   ├── UsageService.swift        # Orchestrator
│   │   │   │   ├── UsagePollingService.swift  # Timer-based refresh
│   │   │   │   └── UsageHistoryService.swift  # Persist history
│   │   │   └── Views/
│   │   │       ├── UsageDashboardView.swift   # Full dashboard
│   │   │       ├── CostChartView.swift        # Swift Charts
│   │   │       └── ModelBreakdownView.swift   # Per-model view
│   │   ├── Vault/
│   │   │   ├── Prompts/
│   │   │   │   ├── Prompt.swift              # SwiftData @Model
│   │   │   │   ├── PromptListView.swift
│   │   │   │   ├── PromptEditorView.swift
│   │   │   │   ├── PromptCardView.swift
│   │   │   │   └── PromptCategoryView.swift
│   │   │   ├── Boilerplates/               # Post-MVP
│   │   │   │   ├── Boilerplate.swift
│   │   │   │   ├── BoilerplateListView.swift
│   │   │   │   └── BoilerplateEditorView.swift
│   │   │   ├── Bookmarks/                  # Post-MVP
│   │   │   │   ├── Bookmark.swift
│   │   │   │   └── BookmarkListView.swift
│   │   │   └── VaultMainView.swift         # Tab-based container
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── ProvidersSettingsView.swift
│   │       └── GeneralSettingsView.swift
│   ├── Core/
│   │   ├── Networking/
│   │   │   ├── APIClient.swift            # Generic HTTP client
│   │   │   └── AnthropicAPI.swift         # Anthropic-specific endpoints
│   │   ├── Storage/
│   │   │   ├── KeychainService.swift      # Secure credential storage
│   │   │   └── ExportImportService.swift  # JSON export/import
│   │   ├── Search/
│   │   │   └── SearchService.swift        # FTS5 wrapper
│   │   └── Notifications/
│   │       └── NotificationService.swift  # Usage threshold alerts
│   └── Resources/
│       ├── Assets.xcassets
│       └── Beakon.entitlements
├── BeakonTests/
│   ├── Providers/
│   │   └── ClaudeAPIProviderTests.swift
│   ├── Services/
│   │   └── UsageServiceTests.swift
│   └── Models/
│       └── PromptTests.swift
├── .github/
│   └── workflows/
│       ├── build.yml                     # CI build + test
│       └── release.yml                   # Notarize + DMG + Homebrew
├── Homebrew/
│   └── beakon.rb                         # Cask formula
├── README.md
├── LICENSE                               # MIT
├── CONTRIBUTING.md
└── CHANGELOG.md
```

### 5.2 Tech Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Language | Swift 6 | Native performance, modern concurrency |
| UI | SwiftUI | Declarative, menu bar + window support |
| Persistence | SwiftData | Built-in SQLite, minimal boilerplate |
| Charts | Swift Charts | Native, performant, dark mode support |
| Keychain | Security framework | Secure credential storage |
| Networking | URLSession + async/await | No dependencies needed |
| Search | SQLite FTS5 (via SwiftData raw queries) | Fast full-text search |
| Auto-update | Sparkle | Standard for open source macOS apps |
| Distribution | Homebrew Cask | `brew install --cask beakon` |

### 5.3 Data Storage

**SwiftData Models** — stored in `~/Library/Application Support/Beakon/`

- `Prompt` — prompt library entries
- `Boilerplate` — template snippets (post-MVP)
- `Bookmark` — saved links (post-MVP)
- `UsageHistory` — historical usage snapshots for charts
- `ProviderConfig` — per-provider settings (polling interval, display prefs)

**Keychain** — for sensitive data

- API keys (`sk-ant-api03-*`)
- Session keys (`sk-ant-sid01-*`)
- OAuth tokens (`sk-ant-oat01-*`)

**UserDefaults** — for non-sensitive preferences

- Menu bar display mode (cost / percentage / both)
- Color thresholds
- Notification preferences
- Window position/size
- Selected providers

### 5.4 Minimum System Requirements

- macOS 14.0 (Sonoma) — required for SwiftData
- Apple Silicon or Intel

---

## 6. Security & Privacy

| Concern | Approach |
|---------|----------|
| API keys | Stored in macOS Keychain, never in plaintext |
| Network requests | Only to Anthropic API endpoints, no other outbound calls |
| Telemetry | None. Zero analytics, zero tracking. |
| Local data | SQLite in app sandbox, user-accessible for backup |
| Open source | Full source available for audit |
| Session keys | Encrypted in Keychain, optional expiry tracking |

---

## 7. Milestones & Roadmap

### MVP — Week 1-2

**Week 1: Menu Bar + Usage Tracking**
- [ ] Xcode project setup (SwiftUI, SwiftData, entitlements)
- [ ] Menu bar icon + basic popover
- [ ] Claude Admin API integration (usage + cost endpoints)
- [ ] Settings view (API key input, polling interval)
- [ ] Keychain storage for credentials
- [ ] Basic cost display in menu bar
- [ ] Usage polling service (timer-based)

**Week 2: Vault — Prompt Library**
- [ ] SwiftData Prompt model
- [ ] Vault window (WindowGroup)
- [ ] Prompt list view with search
- [ ] Prompt editor (create/edit)
- [ ] Category sidebar
- [ ] Copy to clipboard action
- [ ] JSON export/import
- [ ] Global keyboard shortcut (⌘+Shift+B)

### Post-MVP — Week 3-4

- [ ] Claude Session API (subscription usage tracking)
- [ ] Claude Code local file parsing
- [ ] Cost chart (Swift Charts, 7d/30d)
- [ ] Model breakdown view
- [ ] Notification system (usage thresholds)
- [ ] Usage history persistence
- [ ] Tag system for prompts

### v1.1 — Month 2

- [ ] Boilerplate module
- [ ] Bookmark module
- [ ] Cursor provider (local file parse)
- [ ] iCloud sync (optional)
- [ ] Sparkle auto-update
- [ ] Homebrew Cask formula
- [ ] GitHub Actions CI/CD (build + notarize + DMG)

### v1.2 — Month 3

- [ ] OpenAI provider
- [ ] Multi-provider dashboard
- [ ] GitHub Copilot provider
- [ ] Prompt sharing (export single prompt as JSON/URL)
- [ ] Spotlight integration (search prompts from Spotlight)

---

## 8. Competitive Landscape

| App | Usage Tracking | Knowledge Base | Multi-Provider | Open Source | Price |
|-----|:-:|:-:|:-:|:-:|-------|
| **Beakon** | ✅ | ✅ | Planned | ✅ | Free |
| Claude Usage Tracker | ✅ | ❌ | ❌ | ✅ | Free |
| ClaudeBar | ✅ | ❌ | ❌ | ✅ | Free |
| SessionWatcher | ✅ | ❌ | Claude + Codex | ❌ | $1.99 |
| Usage4Claude | ✅ | ❌ | ❌ | ✅ | Free |
| ClaudeMeter | ✅ | ❌ | ❌ | ❌ | Paid |

**Beakon's differentiator**: The only open-source macOS app combining AI usage monitoring with a personal prompt/knowledge vault.

---

## 9. Export/Import Schema

```json
{
  "version": "1.0",
  "exportedAt": "2026-03-30T12:00:00Z",
  "app": "Beakon",
  "data": {
    "prompts": [
      {
        "id": "uuid",
        "title": "Code Review System Prompt",
        "content": "You are a senior code reviewer...",
        "category": "System Prompts",
        "tags": ["code-review", "backend"],
        "notes": "Works great with Claude Sonnet",
        "isFavorite": true,
        "usageCount": 42,
        "createdAt": "2026-01-15T10:00:00Z",
        "updatedAt": "2026-03-20T14:30:00Z"
      }
    ],
    "boilerplates": [],
    "bookmarks": []
  }
}
```

---

## 10. Open Questions

1. **iCloud sync**: Should this be opt-in from day one, or deferred to v1.1?
2. **Prompt variables**: Should we support `{{variable}}` interpolation with a fill-in dialog on copy?
3. **Claude.ai auth**: WKWebView login vs manual session key — which first for MVP?
4. **Provider plugins**: Should third-party providers be possible via a plugin system?
5. **Menu bar only vs dock icon**: Should the app appear in the Dock at all?

---

*Last updated: March 30, 2026*
*Author: Özer Subaşı*
*License: MIT*
