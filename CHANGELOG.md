# Changelog

## 0.3.0 - Unreleased

- Added a theme-native Appearance page and remapped navigation to Overview,
  Appearance, Programs, and Doctor.
- Added current theme and background state with handoffs to Omarchy's native
  pickers instead of duplicating them.
- Native theme/background pickers now return to the same Appearance position;
  text-size wheel changes are blocked, scrollbars stay visible, and every page
  uses the same panel height.
- Persistent scrollbars use a reserved right-side gutter instead of covering
  the page content.
- Added installed-font selection, the Omarchy font installer handoff, and
  global text-size stops shared with Quattro's Display panel.
- Added basic bar visibility, position, and transparency controls through
  canonical Omarchy commands.
- Added a read-only monitor summary and direct handoff to Quattro's existing
  Display panel; advanced monitor configuration remains deferred.
- Added one-level, eight-second undo for direct Appearance settings, strict
  input validation, partial provider states, and isolated fixtures.

## 0.2.0 - 2026-08-24

- Replaced Health & Recovery with a dedicated, grouped Doctor experience.
- Added the shell-independent `omapanel doctor` CLI with human, JSON,
  clipboard, and secure file outputs.
- Added privacy-reviewed reports, deterministic severity exit codes,
  per-provider timeouts, and partial results without false-green failures.
- Added reversible `~/.local/bin/omapanel` setup with strict ownership checks.
- Added complete package-to-launcher impact, including hidden launchers, to
  program details and removal previews.
- Added read-only advanced inventory for installed Mise tool versions.
- Added Doctor filters, recommendations, timestamps, theme-native states, and
  keyboard/mouse-complete controls.
- Expanded fixture coverage for timeouts, privacy, output security, setup
  conflicts, Mise, multi-launcher packages, and Doctor models.

## 0.1.0 - 2026-08-21

- Initial Quattro-native OmaPanel proof of concept.
- Added Overview, Programs, and Health & Recovery pages.
- Added application/package/plugin ownership and safe removal routing.
- Added privilege-free diagnostics and recovery handoffs.
- Added keyboard/mouse parity and live theme bindings.
- Added adaptive Overview sizing, readable secondary text, progressive loading
  feedback, and application icons with theme-native fallbacks.
- Added reversible menu and optional `Super+I` setup.
- Added fixture, model, setup, safety, schema, QML lint, and ShellCheck gates.
