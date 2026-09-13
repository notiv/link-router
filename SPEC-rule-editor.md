# Spec: Rule Editor

## Objective

Provide a native window where the user can define the fallback browser and ordered URL-routing rules without hand-editing JSON. Saving writes the exact config consumed by the routing core.

## Tech Stack

- Programmatic AppKit controls on macOS 13+
- A shared app delegate backed by `LRConfigStore`

## Commands

- Build: `make build`
- Test: `make test`
- Package: `make app`

## Project Structure

- `Sources/App/LRConfigWindowController.m` — fallback and ordered rule editor
- `Sources/App/LRAppDelegate.m` — load, edit, validate, save, and route state
- `Tests/` — validation and persistence coverage

## Code Style

Use native labeled controls and explicit save state:

```objective-c
NSPopUpButton *browserPicker = [[NSPopUpButton alloc] init];
[browserPicker addItemsWithTitles:@[@"Safari", @"Google Chrome"]];
[browserPicker setAccessibilityLabel:@"Browser"];
```

The UI uses system colors, spacing, typography, and keyboard-accessible native controls.

## Testing Strategy

- Core tests cover every validation rule used by the editor.
- The packaged app is launched and the editor window is inspected manually.
- Save/reload is verified against a temporary config location in automated tests.

## Boundaries

- Always: show validation errors, preserve rule order, and save atomically.
- Ask first: add automatic Chrome-profile discovery or a richer URL expression language.
- Never: silently discard invalid edits or replace a malformed on-disk config.

## Success Criteria

- Opening LinkRouter directly presents the editor, and reopening the running app restores it.
- The menu opens a dedicated configuration window.
- The user can change the fallback, add/delete/reorder rules, edit host patterns, select Safari or Chrome, and set a Chrome profile.
- Save is disabled or fails visibly when validation fails.
- A successful save updates the JSON file and routing behavior without relaunching the app.
- The config file can still be opened in the user's text editor.

## Open Questions

- None. Chrome profiles use the stable profile directory value entered by the user; automatic discovery is deferred.
