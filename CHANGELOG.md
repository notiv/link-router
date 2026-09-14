# Changelog

## [0.2.0] - 2026-09-14

### Added

- A fully native AppKit rule editor with an adaptive macOS sidebar, standard controls, and a system Liquid Glass action surface on macOS 26 and newer.
- Inline rule creation and hover deletion, plus native drag-and-drop rule reordering.
- A visible `*.` prefix whenever a domain is configured to include subdomains.

### Changed

- The menu-bar menu now focuses on default-browser setup, login launch, opening the rule editor, and quitting; JSON and reload actions remain available inside the editor.
- Rule, fallback, and local-file screens now share consistent alignment, compact browser/profile controls, and appearance-aware system materials.

### Removed

- The embedded WebKit settings surface and its bundled HTML asset.

## [0.1.1] - 2026-09-14

### Added

- A **Start at Login** menu option backed by the macOS Login Items service.
- Clear approval guidance when macOS requires confirmation in System Settings.

### Changed

- Login-item launches now start LinkRouter silently in the menu bar without opening the rule editor.

## [0.1.0] - 2026-09-14

### Added

- Initial preview release with ordered hostname routing, Safari and Chrome targets, Chrome profiles and private windows, local-file handling, and the graphical rule editor.

[0.2.0]: https://github.com/notiv/link-router/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/notiv/link-router/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/notiv/link-router/releases/tag/v0.1.0
