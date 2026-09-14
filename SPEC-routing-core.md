# Spec: Routing Core

## Objective

Provide a small, dependency-free Objective-C library that turns an HTTP, HTTPS, or local file URL and a human-readable JSON config into a browser target. Host rules are evaluated from top to bottom, and the first matching rule wins; file URLs use the fallback target.

The JSON format is:

```json
{
  "default": { "app": "Safari" },
  "rules": [
    {
      "name": "Work",
      "hosts": ["*.example.com", "console.cloud.google.com"],
      "app": "Google Chrome",
      "profile": "Profile 1",
      "private": true
    }
  ]
}
```

An exact host matches only itself. A leading `*.` matches both the base domain and its subdomains. Matching is case-insensitive. `http`, `https`, and local `file` URLs are routable; file URLs have no host match and use the fallback.

## Tech Stack

- Objective-C 2.0 compiled with Apple Clang for macOS 13+
- Foundation only; no third-party dependencies

## Commands

- Build: `make build`
- Focused and full tests: `make test`
- App bundle: `make app`

## Project Structure

- `Sources/Core/` — config schema, validation, persistence, launch plans, and routing
- `Tests/` — standalone unit and temporary-filesystem tests

## Code Style

Use explicit domain names, value types, and errors that describe a user-correctable problem:

```objective-c
- (LRRouteResult *)routeForURL:(NSURL *)URL error:(NSError **)error {
    if (![self validateWebURL:URL error:error]) { return nil; }
    return [self firstMatchingRouteForHost:URL.host] ?: self.defaultRoute;
}
```

Types use an `LR` prefix and `UpperCamelCase`; methods and properties use `lowerCamelCase`. Keep I/O at the boundary and matching logic pure.

## Testing Strategy

- Unit tests cover decoding, encoding, exact and wildcard hosts, precedence, fallback, and rejected URLs/config values.
- Filesystem tests use a unique temporary directory and prove an atomic save can be loaded again.
- Every behavioral implementation begins with a failing focused test.

## Boundaries

- Always: validate URL schemes, host patterns, app names, Chrome profile directory names, and private-mode compatibility.
- Ask first: change the config schema incompatibly or add a dependency.
- Never: execute config text as code, interpolate config into a shell command, or overwrite an invalid existing config automatically.

## Success Criteria

- The sample JSON round-trips without losing rule order.
- First-match routing, wildcard routing, and fallback behavior are covered by passing tests.
- Invalid schemes, host patterns, empty rules, unsafe profile values, and Safari private targets produce actionable errors.
- A default config is created only when the config file does not already exist.

## Open Questions

- None. The initial release intentionally routes by host rather than by path or query string.
