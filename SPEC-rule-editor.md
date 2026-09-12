# Spec: Rule Editor

## Objective

Provide a native window where the user can define the fallback browser and ordered URL-routing rules without hand-editing JSON. Saving writes the exact config consumed by the routing core.

## Tech Stack

- SwiftUI forms and lists on macOS 13+
- Shared observable app model backed by `ConfigStore`

## Commands

- Build: `swift build`
- Test: `swift test`
- Package: `./scripts/build-app.sh`

## Project Structure

- `Sources/LinkRouter/ConfigEditorView.swift` — fallback and ordered rule editor
- `Sources/LinkRouter/AppModel.swift` — load, edit, validate, and save state
- `Tests/LinkRouterCoreTests/` — validation and persistence coverage

## Code Style

Use native labeled controls and explicit save state:

```swift
Picker("Browser", selection: $target.app) {
    Text("Safari").tag(BrowserApp.safari)
    Text("Google Chrome").tag(BrowserApp.chrome)
}
```

The UI uses system colors, spacing, typography, and keyboard-accessible controls.

## Testing Strategy

- Core tests cover every validation rule used by the editor.
- The packaged app is launched and the editor window is inspected manually.
- Save/reload is verified against a temporary config location in automated tests.

## Boundaries

- Always: show validation errors, preserve rule order, and save atomically.
- Ask first: add automatic Chrome-profile discovery or a richer URL expression language.
- Never: silently discard invalid edits or replace a malformed on-disk config.

## Success Criteria

- The menu opens a dedicated configuration window.
- The user can change the fallback, add/delete/reorder rules, edit host patterns, select Safari or Chrome, and set a Chrome profile.
- Save is disabled or fails visibly when validation fails.
- A successful save updates the JSON file and routing behavior without relaunching the app.
- The config file can still be opened in the user's text editor.

## Open Questions

- None. Chrome profiles use the stable profile directory value entered by the user; automatic discovery is deferred.
