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

- Show the current theme/background and hand selection to Omarchy's native
  pickers rather than creating a second theme engine.
- Select installed fonts, hand font installation to the Omarchy menu, and use
  the canonical global text-size control.
- Manage basic bar visibility, position, and transparency with single-level
  undo.
- Summarize current displays and open Quattro's Display panel for brightness,
  scaling, and monitor toggles.

## v0.4 — Devices

- Add a unified Display, Audio, Bluetooth, Network, and Input dashboard with
  current monitor modes and device inventory.
- Use Quattro's live services for Audio, Bluetooth, and Network summaries, then
  open their native panels for substantive changes.
- Offer only Omarchy's canonical touchpad toggle directly, with desired-state
  verification and one-level undo. Hand advanced monitor and input setup to
  their existing configuration editors.
- Keep resolution, refresh, arrangement, persistent monitor profiles, and
  other per-device writes read-only until guarded rollback exists.

## v0.5 — Storage

- Shipped filesystem/mount overview with Btrfs capacity deduplication and
  privacy-conscious UDisks2 NVMe health.
- Shipped explicit, cancellable Home/selected-folder discovery with bounded
  drill-down and default file-manager routing.
- Shipped package cache, orphan, journal, user-cache, and capability-aware
  snapshot insight with confirmed handoffs to canonical workflows.
- Formatting, partition editing, mount changes, direct cleanup, SMART tests,
  and background privilege remain excluded until Omarchy provides a canonical
  safe backend.

## v0.6 — Extended personalization

- Complete the useful remainder of Omarchy's Style surface after Devices and
  Storage, while continuing to hand ownership to the canonical workflows.
- Summarize Hyprland look-and-feel state and open Omarchy's existing config
  editor; do not build a second editor or write `looknfeel.lua` directly.
- Preview Screensaver branding and hand text, image, and restore-default
  actions to Omarchy's existing Style menu workflows, with confirmation before
  reset.
- Preview About branding and hand text, image, and restore-default actions to
  Omarchy's existing Style menu workflows, with confirmation before reset.
- Keep Theme, Background, Unlock, Font, and Menu Bar in Appearance rather than
  duplicating them in this later milestone.

## v0.7 — Safe display configuration

- Require a structured upstream Omarchy API or an independently supervised
  helper; the panel must never write `monitors.lua` by itself.
- Preview the complete proposed layout without changing runtime state, then
  snapshot runtime and persistent configuration before temporary application.
- Start an external rollback guardian before applying. Show keyboard- and
  mouse-accessible Keep/Revert controls with a 15-second countdown.
- Revert automatically on timeout, panel or shell failure, command failure,
  monitor disconnect, or loss of every usable output.
- Persist atomically only after explicit confirmation and successful
  validation, preserving a timestamped backup.
- Test invalid modes, disabled primary outputs, hot unplug, multi-monitor
  layouts, IPC loss, helper crashes, failed persistence, and recovery without
  a visible display before release.

## Core adoption

- Move to reserved ID `omarchy.omapanel`.
- Replace setup-file edits with first-party menu/keybinding registration.
- Ship the terminal doctor in the base system.
- Move software and recovery ownership into structured Omarchy commands.
- Consider a settings-provider contract only after upstream review.
