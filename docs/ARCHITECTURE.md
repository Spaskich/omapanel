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

backend collect health ── isolated checks ── severity model ── recovery cards

selected action ── dry-run validation ── confirmation ── validated adapter
                                                    └─ existing Omarchy workflow
```

Collectors return one JSON document with `schemaVersion: 1`, a UTC generation
time, records, and provider errors. The graphical Programs view requests the
same records as JSONL so Quattro can render them progressively without holding
a large single line in its process collector. A failed provider must not
invalidate successful providers. QML keeps collection asynchronous and
preserves a usable partial view.

Program records use stable source-qualified IDs and flatten their primary
action so they can be represented safely by a `ListModel`. Health records use
`ok`, `info`, `warning`, `error`, or `unknown`; the Overview reports the worst
meaningful status without treating informational rows as failures.

## Backend commands

```text
scripts/omapanel-backend collect programs
scripts/omapanel-backend collect programs --jsonl
scripts/omapanel-backend collect health
scripts/omapanel-backend action --dry-run <adapter> <target>
scripts/omapanel-backend action <adapter> <target>
```

The dry run and real action share target validation and the same argv builder.
Display strings are never evaluated by a shell. Static journal snippets are
the only adapters that invoke `bash -lc`; their content contains no user data.

Supported adapters are package, webapp, TUI, plugin, Flatpak, local launcher,
update, restart shell, user/system journal, Hyprland editor, snapshot
create/restore, orphan review, and sanitized report copy.

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

Pages already share internal records and registry-like conventions, but v0.1
does not publish a third-party provider API. Once OmaPanel has first-party
experience, Omarchy can decide whether existing panels should contribute
summary/action providers through a reviewed shell contract.
