# Repository Guidelines

## Project Structure & Module Organization
The app lives under `RecManga/`, with `Main.swift` bootstrapping `RecMangaApp` and SwiftUI views grouped in `Views/`. Dictionary access and formatting utilities are kept in `Dictionary/`, while bundled assets reside in `Assets.xcassets` and the SQLite dictionary payload in `Resources/jmdict-eng-3.6.1-20250728123310.db`. Preserve this split when adding new screens or services so UI, data, and resources stay isolated and testable.

## Build, Test, and Development Commands
- `open RecManga.xcodeproj` launches the workspace in Xcode; select the RecManga scheme for simulator runs.
- `xcodebuild -scheme RecManga -destination "platform=iOS Simulator,name=iPhone 15" build` performs a CI-friendly build.
- `xcodebuild test -scheme RecManga -destination "platform=iOS Simulator,name=iPhone 15"` executes XCTest bundles once added.
Use the same destination when configuring Continuous Integration to guarantee simulator parity.

## Coding Style & Naming Conventions
Follow Swift API design guidelines: four-space indentation, `UpperCamelCase` for types (e.g. `OCRViewModel`) and `lowerCamelCase` for properties and functions. Group related views and helpers into extensions when they exceed ~150 lines. Prefer SwiftUI modifiers over custom wrappers unless reuse demands it. When persisting assets or resources, use kebab-case filenames and keep localized strings in `Resources/`.

## Testing Guidelines
Add an `RecMangaTests` target that mirrors the module layout (e.g. `Views/` ➔ `ViewsTests/`). Name test cases after the type under test (`ContentViewTests`) and functions with a `test_` prefix describing behavior. Aim for smoke coverage around Live Text flows and dictionary lookups; stub `ImageAnalyzer` where possible. Run `xcodebuild test` locally before pushing and attach new snapshots or fixtures under a dedicated `TestResources/` group.

## Commit & Pull Request Guidelines
Write commits in the imperative mood with a short scope prefix, for example `view: refine empty state copy`. Squash incidental work so each commit remains reviewable. Every pull request should summarize user-visible changes, list validation steps (simulator, device, or tests), and link to the relevant issue or task. Include screenshots for UI tweaks and flag any migrations to the bundled dictionary so reviewers can regenerate artifacts.

## Dictionary Data & Security Notes
The bundled dictionary database is sizeable; avoid checking in regenerated binaries without coordinating on storage impact. If you must update it, document the source and checksum in the PR. Do not log extracted text or user images; rely on in-memory analysis and clear cached OCR results after use.
