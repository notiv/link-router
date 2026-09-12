# LinkRouter Tasks

## Task 1: Scaffold build and routing tests

**Acceptance criteria:**
- [x] Makefile exposes core test, executable, and app-bundle targets.
- [x] Failing tests describe config decoding, matching, validation, and persistence.

**Verification:** `make test` fails on the first unimplemented routing behavior.

**Dependencies:** None

**Files likely touched:** `Makefile`, `Tests/*`, `.gitignore`

## Task 2: Implement routing core

**Acceptance criteria:**
- [x] Valid JSON decodes and round-trips in stable order.
- [x] Exact, wildcard, precedence, fallback, and invalid-input cases pass.
- [x] Config saves atomically and reloads.

**Verification:** `make test`

**Dependencies:** Task 1

**Files likely touched:** `Sources/Core/*`

## Checkpoint: Core

- [x] `make test` passes.
- [ ] `make build` passes.

## Task 3: Implement native routing shell

**Acceptance criteria:**
- [ ] App delegate receives HTTP/HTTPS URLs.
- [ ] Safari and Chrome profile targets use safe, explicit launch paths.
- [ ] Menu exposes status and default-browser action.

**Verification:** `make test` and `make build`

**Dependencies:** Task 2

**Files likely touched:** `Sources/App/*`, `Sources/Core/LRLaunchPlan.*`, `Tests/*`

## Task 4: Package the app

**Acceptance criteria:**
- [ ] Script creates an ad-hoc-signed `dist/LinkRouter.app`.
- [ ] Bundle registers `http` and `https` and runs as an agent app.

**Verification:** `make app` plus `plutil` and `codesign` checks

**Dependencies:** Task 3

**Files likely touched:** `Packaging/Info.plist`, `Makefile`

## Checkpoint: Native Shell

- [ ] App bundle builds and launches without an immediate crash.
- [ ] No default browser setting is changed during verification.

## Task 5: Add rule editor

**Acceptance criteria:**
- [ ] User can edit fallback and ordered rules with native controls.
- [ ] Validation is visible and only valid state is persisted.
- [ ] Saved changes affect routing immediately.

**Verification:** `make test`, `make build`, and manual editor smoke test

**Dependencies:** Tasks 2–4

**Files likely touched:** `Sources/App/LRAppDelegate.*`, `Sources/App/LRConfigWindowController.*`

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
