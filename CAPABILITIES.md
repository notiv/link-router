# Capability Map: LinkRouter

| Module id | Responsibility | Depends on |
|---|---|---|
| `routing-core` | Decode, validate, persist, and evaluate the JSON routing configuration | — |
| `macos-shell` | Receive web URLs and local files, launch Safari or a normal/private Chrome profile, and register as the default browser | `routing-core` |
| `rule-editor` | Provide a native editor for the fallback target and ordered routing rules | `routing-core`, `macos-shell` |

Build order: `routing-core` → `macos-shell` → `rule-editor`
