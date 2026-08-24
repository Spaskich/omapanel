# OmaPanel

**The Omarchy Control Center.** OmaPanel is a keyboard-first, mouse-complete
Quattro panel for appearance, installed software, system health, connected
devices, and reaching the correct Omarchy workflow when something needs to
change.

OmaPanel is intentionally a map, not a second package manager. It collects
state without privilege, explains ownership and impact, and delegates changes
to the existing Omarchy command or workflow that already owns the operation.

## Features

- Responsive Overview, Appearance, Programs, Doctor, and Devices pages.
- Live Omarchy theme, type-scale, spacing, focus, and surface colors.
- Current theme and background preview with native Omarchy picker handoffs that
  return to the same OmaPanel view when selection finishes.
- Unlock-screen customization through Omarchy's existing Style workflow.
- Installed-font selection, global text-size controls, and one-level undo.
- Bar visibility, position, and transparency through canonical Omarchy
  commands.
- Unified Devices page with current monitor modes, input inventory, live audio,
  Bluetooth and network summaries, and native Quattro handoffs.
- Canonical touchpad control with one-level undo; other device changes stay in
  Omarchy's existing panels and configuration workflows.
- Applications, web apps, TUI launchers, plugins, Flatpaks, local launchers,
  and an opt-in advanced Pacman/AUR package list.
- Package/launcher ownership and protected first-party components.
- Isolated Hyprland, Quattro, systemd, disk, Snapper, restart, Pacman, and
  OmaPanel checks with per-provider timeouts and honest unknown states.
- Shell-independent terminal Doctor with sanitized human and JSON reports.
- Package removal impact across every discovered launcher, including hidden
  entries, plus read-only Mise tool visibility.
- Privacy-reviewed clipboard reports and safe handoffs to existing Omarchy
  update, journal, configuration, and recovery workflows.
- Full keyboard navigation with the same selection model used by mouse hover.
- Persistent vertical scrollbars when content overflows and wheel-safe
  text-size controls.
- Idempotent, backed-up, reversible menu and keybinding setup.

## Requirements

- Omarchy 4.x with the Quattro shell.
- `bash`, `jq`, GNU `timeout`, Pacman, and the standard Omarchy commands.
- Flatpak and Mise are optional and disappear or degrade cleanly when
  unavailable.

OmaPanel does not support pre-Quattro Omarchy releases.

## Install

```bash
omarchy plugin add https://github.com/spaskich/omapanel.git --enable
~/.config/omarchy/plugins/spaskich.omapanel/setup
```

The second command is explicit because Omarchy never runs plugin install
hooks. It adds **Setup → OmaPanel**, links `omapanel` into `~/.local/bin`, and
adds `Super+I` only if the shortcut is free. Existing bindings and unrelated
commands are never overwritten.

Install without a shortcut:

```bash
~/.config/omarchy/plugins/spaskich.omapanel/setup --no-keybind
```

Open it directly at any time:

```bash
omarchy-shell shell toggle spaskich.omapanel '{}'
```

Remove the managed menu, keybinding, and CLI integration first:

```bash
~/.config/omarchy/plugins/spaskich.omapanel/setup --remove
```

Then remove the plugin through Omarchy:

```bash
omarchy plugin remove spaskich.omapanel
```

Removing the plugin first can leave a harmless dangling CLI symlink; running
`setup --remove` first keeps the lifecycle completely clean.

## Doctor

The graphical Doctor runs automatically when OmaPanel opens and can be run
again from its page or with `Ctrl+R`. The terminal Doctor uses the same checks
without depending on Quattro:

```bash
omapanel doctor
```

Use the output formats deliberately:

```bash
omapanel doctor --json                 # Structured stdout for jq or tooling
omapanel doctor --copy                 # Sanitized human report to clipboard
omapanel doctor --output report.txt    # New private text file (mode 0600)
omapanel doctor --json --output report.json
```

Human output is for terminal diagnosis and sharing with another person. JSON
is for tests, scripts, issue-template tooling, or a file the user deliberately
attaches to a report. OmaPanel never uploads either format. JSON goes only to
stdout or the explicitly selected path.

Doctor exits with `0` for healthy/informational results, `1` for warnings or
unknown checks, `2` for a confirmed error, and `3` when Doctor itself cannot
run or write the requested destination. Existing output files are never
overwritten.

Shareable reports exclude usernames, hostnames, absolute home paths, network
identifiers, environment/process arguments, journals, and authentication
material. Exact local detail remains inside the graphical result where it is
useful for diagnosis.

## Controls

| Keys | Action |
|---|---|
| `Alt+1/2/3/4/5` | Overview / Appearance / Programs / Doctor / Devices |
| `Tab` / `Shift+Tab` | Move through page controls |
| `Ctrl+Z` | Undo the latest direct setting while offered |
| `Page Up/Down`, `Home/End` | Scroll the Appearance page |
| `↑` `↓` or `j` `k` | Move through rows |
| `Ctrl+N` / `Ctrl+P` | Next / previous row |
| `←` `→` or `h` `l` | Move between pages |
| `/` or `Ctrl+K` | Search programs |
| `Enter` or `Space` | Open details |
| `Delete` or `x` | Request the selected action |
| `Ctrl+R` | Refresh the active page |
| `Backspace` | Leave a narrow-screen detail view |
| `Esc` | Cancel, clear search, go back, or close |

Every control also has a conventional mouse target. No action is hidden behind
right-click.

## Safety model

- Collectors never call sudo, polkit, update servers, or destructive tools.
- Missing/failed checks become **Unknown** rather than a false green result.
- Action targets are validated again against current installed state.
- Every action has a machine-readable dry run and an impact confirmation.
- Terminal handoffs are used wherever privilege or an interactive package
  review may be required.
- First-party plugins are visible but protected.
- “Remove launcher” never claims to uninstall an unknown executable.
- Doctor has no `--fix` mode and never restarts, edits, deletes, updates, or
  restores anything.
- Doctor handoffs only open allowlisted, existing workflows after an explicit
  preview; treatment remains owned by the system tool.
- Appearance writes use narrowly validated Omarchy commands. Theme,
  background, font installation, and display management stay in their native
  pickers or panels.
- Direct font, text-size, and basic bar changes offer an eight-second undo and
  never edit Omarchy configuration themselves.
- Device discovery omits serial and hardware addresses. Local interface and IP
  details stay inside the panel and never enter Doctor exports.
- Touchpad state is the only direct Devices write. Resolution, refresh,
  arrangement, audio, Bluetooth, network, keyboard, and mouse changes are
  delegated to their existing Omarchy workflows.
- Mise versions are visibility-only because `mise uninstall` does not update
  the configuration files that requested a tool.

The graphical panel runs inside `omarchy-shell`; when that process is
unavailable, `omapanel doctor` remains usable from a terminal or SSH session.

## Development and tests

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell OmaPanel.qml
./tests/run
```

Tests replace Omarchy commands with isolated fixtures; the suite never changes
the real desktop, uninstalls software, or repairs anything. See
[Architecture](docs/ARCHITECTURE.md) and
[Roadmap](docs/ROADMAP.md) for the contracts and upstream direction.

## Status

OmaPanel is an early community project. The goal is a useful release
whose code and interaction model can become a credible proposal for Omarchy
core—not a parallel settings ecosystem.
