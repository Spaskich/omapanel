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
snapshot create/restore, orphan review, and sanitized report copy. Doctor only
offers adapters that open a reviewable handoff; it does not expose immediate
treatment as a diagnostic action.

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

Escape precedence is deterministic: confirmation, search text, detail view,
then panel. Theme properties bind directly to `Color.menu`, `Color.popups`,
`Color.accent`, `Color.urgent`, `Color.muted`, and `Style`, so an active theme
change reevaluates the existing surface.

## Extension boundary

Pages already share internal records and registry-like conventions, but v0.2
does not publish a third-party provider API. Once OmaPanel has first-party
experience, Omarchy can decide whether existing panels should contribute
summary/action providers through a reviewed shell contract.
