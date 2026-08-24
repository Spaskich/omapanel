# Architecture

## Responsibility boundary

OmaPanel owns discovery, normalization, presentation, impact explanation, and
routing. It does not own package transactions, privileged configuration,
snapshot restore, service repair, or theme persistence.

The Quattro entry point is an on-demand `panel` plugin. It receives `shell` and
`manifest` from Omarchy's plugin host, reads names and icons from the shared
application library, and finds its backend through `manifest.__sourceDir`.
There is no fixed install path and no second Quickshell process.

## Data flow

```text
Quattro AppLibrary ── names/icons ─┐
                                  ├─ Programs model ── filter/detail/action preview
backend collect programs ─ owners ┘

backend collect doctor ── isolated checks ── severity model ── Doctor cards
                         └─ privacy projection ── human / JSON / copy / file

backend collect appearance ── capability snapshot ── Appearance controls
selected setting ── exact validation ── canonical Omarchy command ── refresh
                                  └─ previous value ── time-bounded UI undo
picker/display request ── allowlisted handoff ── existing Quattro surface

backend collect devices ── displays/input/network detail ─┐
Quickshell device services ── live audio/Bluetooth/network ├─ Devices categories
touchpad desired state ── canonical Omarchy command ───────┘
device/config request ── fixed allowlist ── existing Quattro/editor surface

backend collect storage ── drives/filesystems/UDisks2 ── Storage categories
storage scan <path> ── cancellable JSONL stream ── drill-down space model
maintenance/recovery request ── preview ── fixed Omarchy/Quattro handoff

selected action ── dry-run validation ── confirmation ── validated adapter
                                                    └─ existing Omarchy workflow
```

Programs returns a `schemaVersion: 1` document with a UTC generation time,
records, provider states, and provider errors. The graphical Programs view
requests the same records as JSONL so Quattro can render them progressively
without holding a large single line in its process collector.

Doctor's internal document uses `schemaVersion: 2`. Every external provider
has a bounded timeout and returns a check even when it is unavailable, fails,
or times out. A failed provider cannot invalidate successful checks. `unknown`
is distinct from a verified empty/healthy result.

Program records use stable source-qualified IDs and flatten their primary
action so they can be represented safely by a `ListModel`. Package records
also contain every discovered package-owned launcher. Mise records are
visibility-only because removing an installed version does not update the
configuration that requested it.

Doctor records use `ok`, `info`, `warning`, `error`, or `unknown`; the Overview
reports the worst meaningful status without treating informational rows as
failures. Internal `detail` may contain local evidence. Shareable reports are
an explicit allowlisted projection containing only report summaries and
recommendations, never a generic serialization of internal detail.

## Backend commands

```text
scripts/omapanel-backend collect programs
scripts/omapanel-backend collect programs --jsonl
scripts/omapanel-backend collect doctor
scripts/omapanel-backend collect health
scripts/omapanel-backend collect appearance
scripts/omapanel-backend collect devices
scripts/omapanel-backend collect storage
scripts/omapanel-backend appearance set <setting> <value>
scripts/omapanel-backend appearance handoff <theme|background|unlock|font-install|display>
scripts/omapanel-backend devices set touchpad <true|false>
scripts/omapanel-backend devices handoff <display|audio|bluetooth|network|monitor-config|input-config>
scripts/omapanel-backend storage scan <absolute-directory>
scripts/omapanel-backend storage choose-directory
scripts/omapanel-backend storage open <absolute-directory>
scripts/omapanel-backend doctor [--json] [--copy | --output <path>]
scripts/omapanel-backend action --dry-run <adapter> <target>
scripts/omapanel-backend action <adapter> <target>
```

`collect health` is a v0.2 compatibility alias for `collect doctor`. The public
`omapanel doctor --json` report has its own `schemaVersion: 1` contract and is
the only diagnostic format intended for external automation.

The dry run and real action share target validation and the same argv builder.
Display strings are never evaluated by a shell. Static journal snippets are
the only adapters that invoke `bash -lc`; their content contains no user data.

Supported adapters are package, webapp, TUI, plugin, Flatpak, local launcher,
update/restart review, restart shell, user/system journal, Hyprland editor,
snapshot create/restore, orphan review, package-cache prune, disk speed test,
and sanitized report copy. Doctor only
offers adapters that open a reviewable handoff; it does not expose immediate
treatment as a diagnostic action.

Appearance has a separate internal contract because font, text-size, and basic
bar choices are direct settings rather than destructive workflow handoffs.
The backend accepts only installed font families, curated text-size stops,
fixed bar values, and fixed handoff names. It always invokes argv arrays. The
UI serializes writes, refreshes state after completion, and retains one prior
value for eight seconds. Theme/background selection, font installation, and
display changes remain owned by Omarchy's existing pickers and panels.

Devices uses an internal `schemaVersion: 1` document. Timeout-bounded
Hyprland/Omarchy providers normalize monitor modes, input inventory, touchpad
state, and local connection detail without serial or hardware addresses.
PipeWire, Bluetooth, and NetworkManager state binds directly to the same
Quickshell modules used by Quattro. Provider failure is isolated by category.

The touchpad desired-state command is the only direct Devices write. It accepts
literal booleans, calls `omarchy toggle touchpad on|off`, verifies the canonical
state, serializes UI writes, and exposes the previous value for eight seconds.
All other device buttons are fixed handoffs. Monitor configuration remains
read-only until an external guardian can restore runtime and persistent state
independently of the panel process.

Storage uses an internal `schemaVersion: 1` document. `lsblk` and `findmnt`
provide physical and mounted topology; repeated Btrfs subvolumes sharing the
same source and capacity collapse into one filesystem record. UDisks2 exposes
read-only NVMe health. The projection never includes serials, UUIDs, WWNs, or
other stable hardware identifiers.

Folder scans are a separate JSONL contract with `started`, `entry`,
`completed`, `cancelled`, and `error` events. Paths must resolve to absolute,
readable directories. GNU `du` stays on one filesystem, does not follow
symlinks, and is terminated with the backend when cancelled. Scan state is not
persisted. Opening a result uses the desktop's default file handler and grants
no file mutation capability.

Maintenance collection is read-only. The package-cache preview runs the dry
form of the same keep-two policy used by `omarchy update pkg prune`; orphan
review uses Pacman's dependency query. Snapper scopes are listed without
privilege, and permission denial is a first-class capability state. Cache
prune, orphan review, snapshot create/restore, and disk speed testing are
allowlisted previews that hand execution to their existing owner.

## Terminal and report boundary

`bin/omapanel` resolves its own plugin root and delegates Doctor to the shared
backend. Setup links it from `~/.local/bin`; it is not copied or installed as a
second package. Setup refuses command conflicts and removes only a link that
resolves to its own entry point.

Human and JSON reports are rendered from the same privacy projection. Nothing
uploads automatically. `--output` publishes a new mode-0600 file atomically
and refuses existing paths. Exit codes describe diagnostic severity separately
from report-generation failure.

## UI state

The root owns one cursor for each list. Keyboard movement and mouse hover both
write that cursor; row rendering never maintains an independent hover
highlight. Wide screens show list and details together. Narrow screens switch
between them while preserving the cursor and use Backspace/Esc to return.

Escape precedence is deterministic: open selector, confirmation, search text,
detail view, then panel. Theme properties bind directly to `Color.menu`, `Color.popups`,
`Color.accent`, `Color.urgent`, `Color.muted`, and `Style`, so an active theme
change reevaluates the existing surface.

## Extension boundary

Pages already share internal records and registry-like conventions, but
OmaPanel does not publish a third-party provider API. Once it has first-party
experience, Omarchy can decide whether existing panels should contribute
summary/action providers through a reviewed shell contract.
