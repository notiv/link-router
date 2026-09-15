# Changelog

## [0.2.1] - 2026-09-15

### Fixed

- Double-clicking a local HTML file no longer does nothing. Becoming the default browser makes macOS hand LinkRouter the `public.html` content type regardless of what the bundle declares, so 0.2.0 stopped handling those files while the system kept sending them. Local files are now forwarded to the browser unmatched links go to.
- **Set as Default Browser** now hands the `public.html` and `public.xhtml` content types back to that same browser, so macOS stops routing documents through LinkRouter in the first place.
- Routing and launch failures now raise an alert instead of only writing to the menu-bar status, which is invisible in an agent app with no windows.
- Failures across a batch of URLs are collected and reported once, so one bad link no longer blocks the rest behind a modal.

### Changed

- `file://` URLs on a remote authority are rejected; only an empty authority or `localhost` counts as a local file.

## [0.2.0] - 2026-09-14

### Added

- A fully native AppKit rule editor with an adaptive macOS sidebar, standard controls, and a system Liquid Glass action surface on macOS 26 and newer.
- Inline rule creation and hover deletion, plus native drag-and-drop rule reordering.
- A visible `*.` prefix whenever a domain is configured to include subdomains.

### Changed

- The menu-bar menu now focuses on default-browser setup, login launch, opening the rule editor, and quitting; JSON and reload actions remain available inside the editor.
- Rule and fallback screens now share consistent alignment, compact browser/profile controls, and appearance-aware system materials.
- The rule title in the detail pane now starts level with the Rules header in the sidebar.

### Fixed

- App icon generation now writes the multi-resolution ICNS directly, with a high-resolution extraction check during bundle verification.
- Untouched newly added rules can be removed immediately without an unnecessary confirmation sheet.
- The inline removal control now has correct hit testing throughout its animation; configured and saved rules retain their confirmation sheet.
- Detail titles now align at the top with the Rules heading.

### Removed

- The embedded WebKit settings surface and its bundled HTML asset.
- Local-file and HTML-document handling, so LinkRouter no longer intercepts `file://` workflows.

## [0.1.1] - 2026-09-14

### Added

- A **Start at Login** menu option backed by the macOS Login Items service.
- Clear approval guidance when macOS requires confirmation in System Settings.

### Changed

- Login-item launches now start LinkRouter silently in the menu bar without opening the rule editor.

## [0.1.0] - 2026-09-14

### Added

- Initial preview release with ordered hostname routing, Safari and Chrome targets, Chrome profiles and private windows, local-file handling, and the graphical rule editor.

[0.2.1]: https://github.com/notiv/link-router/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/notiv/link-router/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/notiv/link-router/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/notiv/link-router/releases/tag/v0.1.0
