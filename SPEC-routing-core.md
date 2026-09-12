# Spec: Routing Core

## Objective

Provide a small, dependency-free Swift library that turns an HTTP or HTTPS URL and a human-readable JSON config into a browser target. Rules are evaluated from top to bottom, and the first matching rule wins.

The JSON format is:

```json
{
  "default": { "app": "Safari" },
  "rules": [
    {
      "name": "Work",
      "hosts": ["*.example.com", "console.cloud.google.com"],
      "app": "Google Chrome",
      "profile": "Profile 1"
    }
  ]
}
```

An exact host matches only itself. A leading `*.` matches both the base domain and its subdomains. Matching is case-insensitive. Only `http` and `https` URLs are routable.

## Tech Stack

- Swift 6 package, compiled in Swift language mode 5 for macOS 13+
- Foundation and Swift Testing/XCTest only; no third-party dependencies

## Commands

- Build: `swift build`
- Focused tests: `swift test --filter RoutingCoreTests`
- Full tests: `swift test`
- Format check: `swift-format lint --recursive Sources Tests` when `swift-format` is installed

## Project Structure

- `Sources/LinkRouterCore/` — config schema, validation, persistence, and routing
- `Tests/LinkRouterCoreTests/` — unit and temporary-filesystem tests

## Code Style

Use explicit domain names, value types, and errors that describe a user-correctable problem:

```swift
public func target(for url: URL) throws -> BrowserTarget {
    guard let host = url.host else { throw RoutingError.missingHost }
    return rules.first { $0.matches(host: host) }?.target ?? defaultTarget
}
```

Types use `UpperCamelCase`; methods and properties use `lowerCamelCase`. Keep I/O at the boundary and matching logic pure.

## Testing Strategy

- Unit tests cover decoding, encoding, exact and wildcard hosts, precedence, fallback, and rejected URLs/config values.
- Filesystem tests use a unique temporary directory and prove an atomic save can be loaded again.
- Every behavioral implementation begins with a failing focused test.

## Boundaries

- Always: validate URL schemes, host patterns, app names, and Chrome profile directory names.
- Ask first: change the config schema incompatibly or add a dependency.
- Never: execute config text as code, interpolate config into a shell command, or overwrite an invalid existing config automatically.

## Success Criteria

- The sample JSON round-trips without losing rule order.
- First-match routing, wildcard routing, and fallback behavior are covered by passing tests.
- Invalid schemes, host patterns, empty rules, and unsafe profile values produce actionable errors.
- A default config is created only when the config file does not already exist.

## Open Questions

- None. The initial release intentionally routes by host rather than by path or query string.
