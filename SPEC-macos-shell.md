# Spec: macOS Shell

## Objective

Deliver a native, menu-bar-only macOS app named LinkRouter. macOS sends it HTTP, HTTPS, and local file URLs; it evaluates the config and immediately opens the chosen target in Safari or Google Chrome. Chrome targets may include a profile directory such as `Default` or `Profile 1` and may request an Incognito window.

## Tech Stack

- Objective-C 2.0 and AppKit on macOS 13+
- `NSStatusItem` for the menu-bar interface
- `NSApplicationDelegate.application(_:open:)` for URL delivery
- `NSWorkspace` for app lookup, launching, and default-handler registration
- `SMAppService.mainAppService` for user-controlled launch at login
- `NSTask` with typed arguments for Chrome profile and Incognito launches; no shell

## Commands

- Build executable: `make build`
- Test: `make test`
- Build app bundle: `make app`
- Launch packaged app: `open dist/LinkRouter.app`

## Project Structure

- `Sources/App/` — AppKit entry point, delegate, app state, browser launcher, and editor
- `Sources/Core/` — shared routing behavior
- `Packaging/Info.plist` — app identity, URL schemes, and agent-app setting
- `Makefile` — reproducible build, test, `.app` assembly, and ad-hoc signing
- `dist/` — ignored build output

## Code Style

Platform side effects sit behind small protocols so core behavior remains testable:

```objective-c
@protocol LRBrowserLaunching <NSObject>
- (void)openURL:(NSURL *)URL target:(LRBrowserTarget *)target;
@end
}
```

All user-interface mutations occur on the main thread.

## Testing Strategy

- Unit-test launch-plan creation without opening real browsers.
- Build and inspect the final bundle to verify its executable and URL declarations.
- Runtime smoke-test launching the menu-bar app without changing the user's default browser.

## Boundaries

- Always: resolve installed apps by bundle identifier and pass URLs/profile names as separate arguments.
- Ask first: install into `/Applications` or change the user's default browser outside an explicit button click.
- Never: route schemes other than HTTP, HTTPS, and local files; invoke `sh -c`; log browsing history; or collect telemetry.

## Success Criteria

- The packaged app launches as a status item and does not appear in the Dock.
- A checked menu option registers the app to launch silently at login, and reflects approval changes made in System Settings.
- Its bundle declares itself capable of handling `http`, `https`, `file`, and HTML documents.
- A menu action requests LinkRouter as the default for web links, file URLs, and HTML documents through supported AppKit APIs.
- Incoming URLs are sent to the resolved target, including the configured Chrome profile and Incognito option.
- Missing browsers and invalid config are reported in the menu without crashing.

## Open Questions

- None. Installing the app and approving a default-browser change remain explicit user actions.
