# Implementation Plan: LinkRouter

## Overview

Build a dependency-free native macOS menu-bar browser router with a JSON config and a SwiftUI rule editor. The implementation is risk-first: prove matching, persistence, and safe launch plans before adding platform integration and UI.

## Architecture Decisions

- Compile a small Foundation core and AppKit executable with Apple Clang so logic is testable without launching apps or requiring full Xcode.
- Keep the reference config's readable `app`, `profile`, and ordered `hosts` fields.
- Use AppKit's supported URL delivery and default-handler APIs; keep the app menu-bar-only with `LSUIElement` and `NSStatusItem`.
- Launch Chrome's resolved executable with an argument array so profile selection works without shell parsing.
- Build a local `.app` bundle through a checked-in Makefile because the installed Swift compiler and SDK patch versions do not match, while Apple Clang is functional.

## Task List

### Phase 1: Foundation

- [ ] Task 1: Scaffold the Clang build and write failing routing/config tests.
- [ ] Task 2: Implement validated config matching and atomic persistence.

### Checkpoint: Foundation

- [ ] Focused and full tests pass.
- [ ] Core builds without warnings.

### Phase 2: Native Shell

- [ ] Task 3: Add browser launch planning and the macOS URL-handling menu-bar shell.
- [ ] Task 4: Add Info.plist and reproducible Makefile `.app` packaging.

### Checkpoint: Native Shell

- [ ] Bundle metadata declares HTTP/HTTPS and `LSUIElement`.
- [ ] Packaged app launches and remains running as a menu-bar app.

### Phase 3: Rule Editor and Handoff

- [ ] Task 5: Add the native fallback/rule editor with visible validation and save state.
- [ ] Task 6: Document configuration, build, installation, and verification.

### Checkpoint: Complete

- [ ] Full tests and release build pass.
- [ ] Editor save/reload and a non-destructive routing dry run work end-to-end.
- [ ] Security and accessibility review finds no blocking issue.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Chrome ignores profile arguments when already running | High | Execute Chrome's bundle-resolved binary directly; keep argument construction covered by tests |
| App cannot become an HTTP handler | High | Declare both schemes in Info.plist and use the macOS 12+ `NSWorkspace` setter |
| Config edits corrupt the only file | High | Validate before saving and use atomic file replacement |
| Routing loops back into LinkRouter | High | Resolve Safari/Chrome explicitly rather than using the system default opener |
| Full Xcode is unavailable | Medium | Use SwiftPM plus a deterministic app-bundle packaging script |

## Open Questions

- None blocking. The initial editor uses manually entered Chrome profile directories rather than depending on Chrome's undocumented profile metadata.
