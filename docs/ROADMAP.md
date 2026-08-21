# Roadmap

## v0.1 — Proof of concept

- Theme-native Overview, Programs, and Health & Recovery.
- Friendly software inventory with advanced packages.
- Privilege-free checks and confirmed handoffs.
- Keyboard-first and mouse-complete interaction.
- Community plugin setup and marketplace release.

## v0.2 — Reliability and terminal recovery

- Make Doctor a dedicated panel page backed by isolated, timeout-bounded
  checks with partial results and explicit recommendations.
- Add `omapanel doctor` for terminal and SSH recovery when Quattro is
  unavailable, without adding repair or privilege modes.
- Export human and structured privacy-reviewed reports only to destinations
  explicitly selected by the user.
- Show complete discovered launcher impact for package removal and add
  visibility-only Mise-managed tools.
- Install the CLI through a reversible, ownership-checked user symlink.
- Propose canonical `omarchy software list --json` and removal-routing commands
  so ownership logic can eventually leave the plugin.

## v0.3 — Appearance

- Current theme/background previews, theme switching, font scaling, and bar
  configuration.
- Delegate to Omarchy's theme, font, background, and bar commands; do not
  create a second theme engine.

## v0.4 — Devices

- Displays and per-device keyboard, mouse, and touchpad settings.
- Audio, Bluetooth, and network summaries using Quattro's existing services.
- Any editable configuration must be transactional: backup, validate, apply,
  and offer rollback.

## v0.5 — Storage

- Filesystem/mount overview, large-directory discovery, SMART health, cache and
  orphan review, and snapshot browsing.
- Start read-only. Privileged actions require a narrow upstream/polkit API.
- Formatting, partition editing, and other destructive disk operations remain
  excluded until Omarchy provides a canonical safe backend.

## Core adoption

- Move to reserved ID `omarchy.omapanel`.
- Replace setup-file edits with first-party menu/keybinding registration.
- Ship the terminal doctor in the base system.
- Move software and recovery ownership into structured Omarchy commands.
- Consider a settings-provider contract only after upstream review.
