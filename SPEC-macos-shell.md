# Spec: macOS Shell

## Objective

Deliver a native, menu-bar-only macOS app named LinkRouter. macOS sends it HTTP and HTTPS URLs; it evaluates the config and immediately opens the chosen target in Safari or Google Chrome. Chrome targets may include a profile directory such as `Default` or `Profile 1`.

## Tech Stack

- SwiftUI `MenuBarExtra` and AppKit on macOS 13+
- `NSApplicationDelegate.application(_:open:)` for URL delivery
- `NSWorkspace` for app lookup, launching, and default-handler registration
- `Process` with typed arguments for Chrome profile launches; no shell

## Commands

- Build package: `swift build`
- Test: `swift test`
- Build app bundle: `./scripts/build-app.sh`
- Launch packaged app: `open dist/LinkRouter.app`

## Project Structure

- `Sources/LinkRouter/` — SwiftUI entry point, AppKit delegate, app state, and browser launcher
- `Packaging/Info.plist` — app identity, URL schemes, and agent-app setting
- `scripts/build-app.sh` — reproducible local `.app` assembly and ad-hoc signing
- `dist/` — ignored build output

## Code Style

Platform side effects sit behind small protocols so core behavior remains testable:

```swift
protocol BrowserLaunching {
    func open(_ url: URL, in target: BrowserTarget) async throws
}
```

All user-visible state mutations occur on the main actor.

## Testing Strategy

- Unit-test launch-plan creation without opening real browsers.
- Build and inspect the final bundle to verify its executable and URL declarations.
- Runtime smoke-test launching the menu-bar app without changing the user's default browser.

## Boundaries

- Always: resolve installed apps by bundle identifier and pass URLs/profile names as separate arguments.
- Ask first: install into `/Applications`, change the user's default browser outside an explicit button click, or add login-item behavior.
- Never: route non-web schemes, invoke `sh -c`, log browsing history, or collect telemetry.

## Success Criteria

- The packaged app launches as a menu-bar extra and does not appear in the Dock.
- Its bundle declares itself capable of handling both `http` and `https`.
- A menu action requests LinkRouter as the default for both schemes through the supported AppKit API.
- Incoming URLs are sent to the resolved target, including the configured Chrome profile.
- Missing browsers and invalid config are reported in the menu without crashing.

## Open Questions

- None. Installing the app and approving a default-browser change remain explicit user actions.
