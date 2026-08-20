# OmaPanel

**The Omarchy Control Center.** OmaPanel is a keyboard-first, mouse-complete
Quattro panel for understanding installed software, checking system health,
and reaching the correct Omarchy workflow when something needs to change.

OmaPanel is intentionally a map, not a second package manager. It collects
state without privilege, explains ownership and impact, previews every action,
then delegates to Pacman, Flatpak, Snapper, systemd, or the existing Omarchy
command that already owns the operation.

## Proof-of-concept features

- Responsive Overview, Programs, and Health & Recovery pages.
- Live Omarchy theme, type-scale, spacing, focus, and surface colors.
- Applications, web apps, TUI launchers, plugins, Flatpaks, local launchers,
  and an opt-in advanced Pacman/AUR package list.
- Package/launcher ownership and protected first-party components.
- Hyprland, systemd, disk usage, Snapper configuration, restart state, Pacman
  lock, orphan package, and recovery-tool checks.
- Sanitized clipboard report and safe handoffs to update, journals, snapshots,
  configuration, package review, and shell restart workflows.
- Full keyboard navigation with the same selection model used by mouse hover.
- Idempotent, backed-up, reversible menu and keybinding setup.

## Requirements

- Omarchy 4.x with the Quattro shell.
- `bash`, `jq`, Pacman, and the standard Omarchy commands.
- Flatpak is optional and disappears cleanly when unavailable.

OmaPanel does not support pre-Quattro Omarchy releases.

## Install

```bash
omarchy plugin add https://github.com/spaskich/omapanel.git --enable
~/.config/omarchy/plugins/spaskich.omapanel/setup
```

The second command is explicit because Omarchy never runs plugin install
hooks. It adds **Setup → OmaPanel** and adds `Super+I` only if the shortcut is
free. Existing bindings are never overwritten.

Install without a shortcut:

```bash
~/.config/omarchy/plugins/spaskich.omapanel/setup --no-keybind
```

Open it directly at any time:

```bash
omarchy-shell shell toggle spaskich.omapanel '{}'
```

Remove only the managed menu/keybinding integration:

```bash
~/.config/omarchy/plugins/spaskich.omapanel/setup --remove
```

Then remove the plugin through Omarchy:

```bash
omarchy plugin remove spaskich.omapanel
```

## Controls

| Keys | Action |
|---|---|
| `Alt+1/2/3` | Overview / Programs / Health |
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

The graphical panel runs inside `omarchy-shell`; it cannot appear when that
process is completely unavailable. A terminal `omapanel doctor` using the same
collectors is planned for the next milestone.

## Development and tests

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell OmaPanel.qml
./tests/run
```

All action tests use `--dry-run`; the suite never uninstalls or repairs
anything. See [Architecture](docs/ARCHITECTURE.md) and
[Roadmap](docs/ROADMAP.md) for the contracts and upstream direction.

## Status

OmaPanel is an early proof of concept. The goal is a useful community release
whose code and interaction model can become a credible proposal for Omarchy
core—not a parallel settings ecosystem.
