# Contributing to Beakon

Thanks for your interest in contributing to Beakon! Here's how to get started.

## Development Setup

1. **Requirements**: Xcode 16+, macOS 14 (Sonoma)+
2. Clone and open:
   ```bash
   git clone https://github.com/ozersubasi/beakon.git
   cd beakon
   open Beakon.xcodeproj
   ```
3. Press `⌘+R` to build and run

No external package managers or dependencies — everything uses Apple first-party frameworks.

## Architecture

Beakon follows a feature-based module structure:

- **Features/MenuBar** — Menu bar icon and popover
- **Features/Usage** — Provider-based usage tracking system
- **Features/Vault** — Prompt library, boilerplates, bookmarks
- **Features/Settings** — App configuration
- **Core/** — Shared services (networking, keychain, search, notifications)

### Key Patterns

- **UsageProvider protocol**: Each AI service implements this protocol. See `ClaudeAPIProvider.swift`.
- **SwiftData @Model**: All persistent data uses SwiftData models.
- **async/await**: All network and I/O operations use Swift concurrency.
- **No external dependencies**: Keep it that way unless there's a very strong reason.

## How to Contribute

### Bug Reports

Open an issue with:
- macOS version
- Beakon version
- Steps to reproduce
- Expected vs actual behavior

### Feature Requests

Open an issue describing the feature and why it would be useful. For major changes, please discuss first before starting work.

### Pull Requests

1. Fork the repo
2. Create a feature branch from `main`
3. Make your changes
4. Write/update tests if applicable
5. Ensure the project builds without warnings
6. Open a PR with a clear description

### Adding a New Provider

This is the most common type of contribution. See `BEAKON_PRD.md` section 4.1.5 for the provider protocol and follow the existing Claude providers as reference.

## Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI's declarative patterns
- Keep views small and composable
- Use `@Observable` (not `@ObservableObject`) for state
- Prefer `async/await` over Combine
- No force unwraps (`!`) unless you have a very good reason

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
