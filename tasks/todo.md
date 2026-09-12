# LinkRouter Tasks

## Task 1: Scaffold package and routing tests

**Acceptance criteria:**
- [ ] Swift package exposes a core library and macOS executable.
- [ ] Failing tests describe config decoding, matching, validation, and persistence.

**Verification:** `swift test --filter LinkRouterCoreTests`

**Dependencies:** None

**Files likely touched:** `Package.swift`, `Tests/LinkRouterCoreTests/*`, `.gitignore`

## Task 2: Implement routing core

**Acceptance criteria:**
- [ ] Valid JSON decodes and round-trips in stable order.
- [ ] Exact, wildcard, precedence, fallback, and invalid-input cases pass.
- [ ] Config saves atomically and reloads.

**Verification:** `swift test`

**Dependencies:** Task 1

**Files likely touched:** `Sources/LinkRouterCore/*`

## Checkpoint: Core

- [ ] `swift test` passes.
- [ ] `swift build` passes.

## Task 3: Implement native routing shell

**Acceptance criteria:**
- [ ] App delegate receives HTTP/HTTPS URLs.
- [ ] Safari and Chrome profile targets use safe, explicit launch paths.
- [ ] Menu exposes status and default-browser action.

**Verification:** `swift build` and launch-plan unit tests

**Dependencies:** Task 2

**Files likely touched:** `Sources/LinkRouter/*`, `Tests/LinkRouterCoreTests/LaunchPlanTests.swift`

## Task 4: Package the app

**Acceptance criteria:**
- [ ] Script creates an ad-hoc-signed `dist/LinkRouter.app`.
- [ ] Bundle registers `http` and `https` and runs as an agent app.

**Verification:** `./scripts/build-app.sh` plus `plutil` and `codesign` checks

**Dependencies:** Task 3

**Files likely touched:** `Packaging/Info.plist`, `scripts/build-app.sh`

## Checkpoint: Native Shell

- [ ] App bundle builds and launches without an immediate crash.
- [ ] No default browser setting is changed during verification.

## Task 5: Add rule editor

**Acceptance criteria:**
- [ ] User can edit fallback and ordered rules with native controls.
- [ ] Validation is visible and only valid state is persisted.
- [ ] Saved changes affect routing immediately.

**Verification:** `swift test`, `swift build`, and manual editor smoke test

**Dependencies:** Tasks 2–4

**Files likely touched:** `Sources/LinkRouter/AppModel.swift`, `Sources/LinkRouter/ConfigEditorView.swift`, `Sources/LinkRouter/LinkRouterApp.swift`

## Task 6: Document and final-verify

**Acceptance criteria:**
- [ ] README explains build, install, default-browser setup, config, and profiles.
- [ ] All automated and bundle checks pass from a clean tree.

**Verification:** follow every README command and inspect final Git diff/status

**Dependencies:** Tasks 1–5

**Files likely touched:** `README.md`, `tasks/*`

## Checkpoint: Complete

- [ ] All specs' success criteria are satisfied.
- [ ] Tests and release build pass.
- [ ] Runtime, accessibility, and security checks pass.
